"""Excel 원본을 검증한다. 구조 오류가 있으면 종료 코드 1을 반환한다."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lookatyou.cli import validate_main

if __name__ == "__main__":
    sys.exit(validate_main())
