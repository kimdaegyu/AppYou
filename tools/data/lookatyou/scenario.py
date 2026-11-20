"""상황 선택 집계. 전술 점수와 동점 순서에는 더하지 않는다."""


class ScenarioFailure(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message

    def __str__(self):
        return f"{self.code}: {self.message}"


def load_scenario_rows(rows):
    """ScenarioId가 두 번이면 맵으로 합치기 전에 거절한다."""
    seen = set()
    loaded = {}
    for row in rows:
        scenario_id = row.get("scenarioId")
        option_id = row.get("optionId")
        if not scenario_id or not option_id or scenario_id in seen:
            raise ScenarioFailure("invalidAnswer", "상황 응답이 중복되었거나 비어 있습니다.")
        seen.add(scenario_id)
        loaded[scenario_id] = option_id
    return loaded


def summarize_scenarios(pilot, answers, dimension_order=None):
    """완성된 선택만 집계한다. 잘못된 선택지는 점수에 넣지 않는다."""
    mode = pilot.get("scoringMode") or "axis_count"
    if mode not in ("axis_count", "option_points"):
        raise ScenarioFailure("invalidDefinition", "지원하지 않는 상황 배점입니다.")
    scenarios = list(pilot.get("scenarios") or [])
    order = list(dimension_order or _dimension_order(scenarios))
    counts = {dimension_id: 0 for dimension_id in order}
    if len(answers) != len(scenarios):
        raise ScenarioFailure("incomplete", "상황 선택이 끝나지 않았습니다.")
    for scenario in scenarios:
        scenario_id = scenario.get("scenarioId")
        if scenario_id not in answers:
            raise ScenarioFailure("incomplete", "상황 선택이 끝나지 않았습니다.")
        option_id = answers[scenario_id]
        match = [
            item for item in scenario.get("options") or []
            if item.get("optionId") == option_id
        ]
        if len(match) != 1:
            raise ScenarioFailure("invalidAnswer", "이 장면의 선택지가 아닙니다.")
        option = match[0]
        if mode == "axis_count":
            dimension_id = option.get("dimensionId")
            if dimension_id not in counts:
                counts[dimension_id] = 0
                order.append(dimension_id)
            counts[dimension_id] += 1
            continue
        points = option.get("pointsByDimension")
        if not isinstance(points, dict) or not points:
            raise ScenarioFailure("invalidDefinition", "상황 배점이 손상되었습니다.")
        for dimension_id, value in points.items():
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise ScenarioFailure("invalidDefinition", "상황 배점이 손상되었습니다.")
            if dimension_id not in counts:
                counts[dimension_id] = 0
                order.append(dimension_id)
            counts[dimension_id] += value
        for dimension_id in order:
            if dimension_id not in points:
                raise ScenarioFailure("invalidDefinition", "상황 배점이 손상되었습니다.")
    leaders = _leaders(counts, order)
    return {
        "counts": counts,
        "total": sum(counts.values()),
        "kind": _kind(leaders, order),
        "leaders": leaders,
    }


def _dimension_order(scenarios):
    found = []
    for scenario in scenarios:
        options = sorted(
            scenario.get("options") or [],
            key=lambda item: (item.get("sortOrder") or 0, item.get("optionId") or ""),
        )
        for option in options:
            dimension_id = option.get("dimensionId")
            if dimension_id and dimension_id not in found:
                found.append(dimension_id)
    return found


def _leaders(counts, order):
    if not order:
        return []
    top = max(counts[dimension_id] for dimension_id in order)
    return [dimension_id for dimension_id in order if counts[dimension_id] == top]


def _kind(leaders, order):
    if len(order) > 1 and len(leaders) == len(order):
        return "balanced"
    if len(leaders) > 1:
        return "tie"
    return "lead"
