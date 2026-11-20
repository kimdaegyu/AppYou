"""검증 메시지. 파일, 시트, 행, 열을 함께 남긴다."""


class DataError(Exception):
    def __init__(self, message, file=None, sheet=None, row=None, column=None):
        self.message = message
        self.file = file
        self.sheet = sheet
        self.row = row
        self.column = column
        super().__init__(str(self))

    def __str__(self):
        parts = []
        if self.file:
            parts.append(self.file)
        if self.sheet:
            parts.append(self.sheet)
        if self.row is not None:
            parts.append(f"{self.row}행")
        if self.column:
            parts.append(self.column)
        where = " / ".join(parts)
        if where:
            return f"{where}: {self.message}"
        return self.message
