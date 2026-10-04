"""Read a WoW SavedVariables file (a Lua table literal) into Python data."""

import re
from pathlib import Path


class LuaParser:
    """Just enough of the Lua table syntax to read a SavedVariables file."""

    TOKEN = re.compile(
        r"""\s*(?:
            (?P<string>"(?:[^"\\]|\\.)*")
          | (?P<number>-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)
          | (?P<name>[A-Za-z_][A-Za-z_0-9]*)
          | (?P<symbol>[\{\}\[\]=,])
        )""",
        re.VERBOSE | re.IGNORECASE,
    )

    def __init__(self, text):
        self.text = text
        self.pos = 0

    def next_token(self):
        match = self.TOKEN.match(self.text, self.pos)
        if not match:
            return None
        self.pos = match.end()
        return match

    def peek_token(self):
        start = self.pos
        token = self.next_token()
        self.pos = start
        return token

    def parse_value(self):
        token = self.next_token()
        if token is None:
            raise ValueError("unexpected end of file")
        if token.group("string"):
            return token.group("string")[1:-1].encode().decode("unicode_escape")
        if token.group("number"):
            text = token.group("number")
            return float(text) if ("." in text or "e" in text.lower()) else int(text)
        if token.group("name"):
            name = token.group("name")
            if name == "true":
                return True
            if name == "false":
                return False
            if name == "nil":
                return None
            raise ValueError(f"unexpected identifier {name}")
        if token.group("symbol") == "{":
            return self.parse_table()
        raise ValueError(f"unexpected token {token.group(0)!r}")

    def parse_table(self):
        table, array = {}, []
        while True:
            token = self.next_token()
            if token is None:
                raise ValueError("unterminated table")
            symbol = token.group("symbol")
            if symbol == "}":
                return table if table else array
            if symbol == ",":
                continue
            if symbol == "[":
                key = self.parse_value()
                self.next_token()  # ]
                self.next_token()  # =
                table[key] = self.parse_value()
                continue
            # positional value
            self.pos = token.start()
            array.append(self.parse_value())


def load_saved_variables(path):
    text = Path(path).read_text(encoding="utf-8")
    text = text.split("=", 1)[1]  # drop "FiresideDB ="
    parser = LuaParser(text)
    parser.next_token()  # opening {
    return parser.parse_table()
