"""생성 JSON을 읽어 합성 응답을 만든다. 공통 엔진에 집단 상수를 넣지 않는다."""

import argparse
import hashlib
import json
import random
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lookatyou.engine import QuizFailure, score_integer_values

ROOT = Path(__file__).resolve().parents[2]

# 첨부 v0.2 시뮬레이터와 같은 Random 호출 순서. 축 순서는 규칙의 tiePriority다.
BASELINE_PROFILE = {
    "name": "baseline_v0.2",
    "seed": 20261120,
    "sensitivitySeed": 20261121,
    "sensitivitySample": 10000,
    "groups": [
        {"name": "무작위_독립", "size": 15000, "method": "uniform"},
        {"name": "잠재성향_독립", "size": 30000, "method": "latent", "low": 1.3, "high": 4.7, "noise": 0.7},
        {
            "name": "아키타입",
            "size": 35000,
            "method": "archetype",
            "noise": 0.5,
            "centers": [
                [4.6, 2.0, 1.9],
                [4.5, 4.2, 1.7],
                [4.5, 2.2, 4.3],
                [2.0, 4.7, 1.8],
                [1.8, 4.5, 4.2],
                [4.2, 4.6, 1.8],
                [1.9, 2.0, 4.7],
                [1.7, 4.1, 4.6],
                [4.2, 1.8, 4.6],
                [3.0, 3.0, 3.0],
                [4.7, 4.7, 4.7],
                [1.3, 1.3, 1.3],
            ],
        },
        {
            "name": "경계값_집중",
            "size": 10000,
            "method": "boundary",
            "noise": 0.35,
            "center": [2.0, 4.0],
            "firstGap": [0.0, 0.33, 0.5, 0.68, 0.9],
            "secondGap": [0.0, 0.27, 0.47, 0.71],
        },
        {
            "name": "응답태도_극단",
            "size": 10000,
            "method": "pattern",
            "patterns": {
                "ones": [1],
                "threes": [3],
                "fives": [5],
                "alternating": [1, 5],
                "high-mid": [5, 4, 3],
                "rhythm": [1, 2, 3, 4, 5, 4],
            },
        },
    ],
}

PUBLISHED_BASELINE = {
    "formations": {
        "3-4-3": 7154,
        "3-5-2": 10176,
        "3-6-1": 10020,
        "4-2-4": 10658,
        "4-3-3": 7921,
        "4-4-2": 17123,
        "4-5-1": 7675,
        "5-3-2": 8610,
        "5-4-1": 9092,
        "6-3-1": 11571,
    },
    "sensitivity": {
        "무작위_독립": {"tested": 1447, "changed": 278},
        "잠재성향_독립": {"tested": 3122, "changed": 394},
        "아키타입": {"tested": 3501, "changed": 450},
        "경계값_집중": {"tested": 975, "changed": 200},
        "응답태도_극단": {"tested": 955, "changed": 50},
    },
}


def load_quiz(bundle, quiz_id):
    path = Path(bundle) / "quizzes" / f"{quiz_id}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def run_profile(quiz, profile, formation_of):
    """formation_of(resultTypeId) -> 표시 문자열. 엔진은 ID만 반환한다."""
    rng = random.Random(profile["seed"])
    questions = [item for item in quiz["questions"] if item.get("isActive")]
    questions.sort(key=lambda item: (item["sortOrder"], item["questionId"]))
    axes = list(quiz["rule"]["tiePriority"])
    records = []
    per_group = {}
    total = Counter()
    for group in profile["groups"]:
        counts = Counter()
        for _ in range(group["size"]):
            values = _sample(group, questions, axes, rng)
            outcome = score_integer_values(quiz, values, allow_pending=True)
            formation = formation_of(outcome["resultTypeId"])
            records.append((group["name"], values, outcome["resultTypeId"], formation))
            counts[formation] += 1
        per_group[group["name"]] = dict(sorted(counts.items()))
        total.update(counts)
    sensitivity = _sensitivity(quiz, records, formation_of, profile)
    payload = json.dumps(
        {"seed": profile["seed"], "groups": profile["groups"], "quizId": quiz["quizId"], "dataVersion": quiz["dataVersion"]},
        ensure_ascii=False,
        sort_keys=True,
    )
    return {
        "quizId": quiz["quizId"],
        "dataVersion": quiz["dataVersion"],
        "ruleVersion": quiz["rule"]["ruleVersion"],
        "profile": profile["name"],
        "seed": profile["seed"],
        "inputHash": hashlib.sha256(payload.encode("utf-8")).hexdigest(),
        "tested": sum(group["size"] for group in profile["groups"]),
        "formations": dict(sorted(total.items())),
        "perGroup": per_group,
        "sensitivity": sensitivity,
    }


def _sample(group, questions, axes, rng):
    method = group["method"]
    if method == "uniform":
        return [rng.randint(1, 5) for _ in questions]
    if method == "latent":
        targets = {axis: rng.uniform(group["low"], group["high"]) for axis in axes}
        return [_clamp(rng.gauss(targets[item["dimensionId"]], group["noise"])) for item in questions]
    if method == "archetype":
        center = rng.choice(group["centers"])
        targets = dict(zip(axes, center))
        return [_clamp(rng.gauss(targets[item["dimensionId"]], group["noise"])) for item in questions]
    if method == "boundary":
        center = rng.uniform(*group["center"])
        first = rng.choice(group["firstGap"])
        second = rng.choice(group["secondGap"])
        targets = dict(zip(axes, rng.sample([center, center + first, center - second], len(axes))))
        return [_clamp(rng.gauss(targets[item["dimensionId"]], group["noise"])) for item in questions]
    if method == "pattern":
        name = rng.choice(list(group["patterns"]))
        cycle = group["patterns"][name]
        return [cycle[index % len(cycle)] for index in range(len(questions))]
    raise QuizFailure("unsupportedStrategy", method)


def _sensitivity(quiz, records, formation_of, profile):
    rng = random.Random(profile["sensitivitySeed"])
    chosen = rng.sample(records, profile["sensitivitySample"])
    tested = Counter()
    changed = Counter()
    for group, values, result_id, formation in chosen:
        index = rng.randrange(len(values))
        altered = list(values)
        value = altered[index]
        if value == 1:
            altered[index] = 2
        elif value == 5:
            altered[index] = 4
        else:
            altered[index] = value + rng.choice([-1, 1])
        outcome = score_integer_values(quiz, altered, allow_pending=True)
        tested[group] += 1
        if formation_of(outcome["resultTypeId"]) != formation:
            changed[group] += 1
    return {
        group: {"tested": tested[group], "changed": changed[group]}
        for group in tested
    }


def _clamp(value):
    return max(1, min(5, int(round(value))))


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--quiz", default="life_tactics")
    args = parser.parse_args(argv)
    quiz = load_quiz(args.bundle, args.quiz)
    formations = {
        item["resultTypeId"]: item["formation"]
        for item in quiz["resultTypes"]
    }
    report = run_profile(quiz, BASELINE_PROFILE, lambda result_id: formations[result_id])
    json.dump(report, sys.stdout, ensure_ascii=False, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
