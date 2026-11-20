"""validate.py와 build.py가 공유하는 실행 진입점."""

import argparse
import sys
from pathlib import Path

from lookatyou.errors import DataError
from lookatyou.serialize import publish
from lookatyou.validate import validate_tables
from lookatyou.workbook import read_sources

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SOURCE = ROOT / "data" / "source"
DEFAULT_DESTINATION = ROOT / "app" / "assets" / "data"


def validate_main(argv=None):
    _configure_stdio()
    parser = _parser()
    parser.add_argument(
        "--strict-release",
        action="store_true",
        help="출시 목록에서 빠지는 진단이나 미검수 번역이 있으면 실패합니다.",
    )
    args = parser.parse_args(argv)
    errors, warnings, _versions = _load(args.source)
    _print_messages(errors, warnings)
    if errors:
        return 1
    if args.strict_release and _release_blocked(warnings):
        print("error: 출시 조건에 맞지 않는 항목이 있습니다.", file=sys.stderr)
        return 1
    print(_summary(warnings))
    return 0


def build_main(argv=None):
    _configure_stdio()
    parser = _parser()
    parser.add_argument(
        "--destination",
        type=Path,
        default=DEFAULT_DESTINATION,
        help="버전별 JSON을 쓸 폴더",
    )
    args = parser.parse_args(argv)
    errors, warnings, versions = _load(args.source)
    _print_messages(errors, warnings)
    if errors:
        print("error: JSON을 쓰지 않았습니다. 기존 생성 파일을 유지합니다.", file=sys.stderr)
        return 1
    if not versions:
        print("error: 쓸 데이터 버전이 없습니다. 기존 생성 파일을 유지합니다.", file=sys.stderr)
        return 1
    try:
        publish(versions, args.destination, warnings)
    except Exception as error:  # noqa: BLE001 - 교체 실패도 기존 파일을 남긴다.
        print(f"error: JSON 교체에 실패했습니다. {error}", file=sys.stderr)
        return 1
    print(_summary(warnings))
    print(f"wrote {args.destination}")
    return 0


def _parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    return parser


def _load(source):
    tables, read_errors = read_sources(source)
    if read_errors:
        return read_errors, [], {}
    return validate_tables(tables)


def _print_messages(errors, warnings):
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)


def _release_blocked(warnings):
    return any(isinstance(item, DataError) for item in warnings)


def _summary(warnings):
    return f"warnings: {len(warnings)}"


def _configure_stdio():
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is not None:
            reconfigure(encoding="utf-8", errors="replace")
