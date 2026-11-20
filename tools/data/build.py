"""검증에 통과한 Excel만 JSON 번들로 바꾼다. 실패하면 기존 출력을 그대로 둔다."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lookatyou.cli import build_main

if __name__ == "__main__":
    sys.exit(build_main())
