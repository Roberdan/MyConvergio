"""Entry point: python3 -m dashboard_textual"""

import sys
from .app import ControlCenterApp


def main() -> None:
    db_path = sys.argv[1] if len(sys.argv) > 1 else None
    app = ControlCenterApp(db_path=db_path)
    app.run()


if __name__ == "__main__":
    main()
