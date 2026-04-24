import specify_cli as cli


class FakeStream:
    def __init__(self, encoding: str | None):
        self.encoding = encoding
        self.calls: list[dict[str, str]] = []

    def reconfigure(self, **kwargs):
        self.calls.append(kwargs)


def test_windows_console_fallback_uses_replace_for_non_utf(monkeypatch):
    stdout = FakeStream("cp1252")
    stderr = FakeStream("cp1252")

    monkeypatch.setattr(cli.os, "name", "nt", raising=False)
    monkeypatch.setattr(cli.sys, "stdout", stdout)
    monkeypatch.setattr(cli.sys, "stderr", stderr)

    cli._enable_windows_console_fallback()

    assert stdout.calls == [{"errors": "replace"}]
    assert stderr.calls == [{"errors": "replace"}]


def test_windows_console_fallback_skips_utf8_streams(monkeypatch):
    stdout = FakeStream("utf-8")
    stderr = FakeStream("utf8")

    monkeypatch.setattr(cli.os, "name", "nt", raising=False)
    monkeypatch.setattr(cli.sys, "stdout", stdout)
    monkeypatch.setattr(cli.sys, "stderr", stderr)

    cli._enable_windows_console_fallback()

    assert stdout.calls == []
    assert stderr.calls == []


def test_show_banner_falls_back_when_console_cannot_encode(monkeypatch):
    calls: list[object] = []

    def fake_print(renderable="", *args, **kwargs):
        if not calls:
            calls.append("unicode-error")
            raise UnicodeEncodeError("cp1252", "████", 0, 1, "boom")
        calls.append(renderable)

    monkeypatch.setattr(cli.console, "print", fake_print)

    cli.show_banner()

    assert calls[0] == "unicode-error"
    assert len(calls) == 4
    assert str(calls[1].renderable) == "SPECIFY"
    assert str(calls[2].renderable) == cli.TAGLINE
    assert calls[3] == ""