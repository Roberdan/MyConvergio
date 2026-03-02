"""Entry point: python3 -m dashboard_textual"""

import argparse
import sys

from .app import ControlCenterApp


def main() -> None:
    parser = argparse.ArgumentParser(description="Claude Control Center TUI")
    parser.add_argument("--plan", type=int, help="Drill into specific plan")
    parser.add_argument("--db", type=str, help="Path to dashboard.db")
    args = parser.parse_args()

    app = ControlCenterApp(db_path=args.db)
    app.run()


if __name__ == "__main__":
    main()
