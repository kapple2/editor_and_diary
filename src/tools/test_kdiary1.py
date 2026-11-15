"""KDIARY first run: set the password, enter today's date, the calendar appears."""
import dsession as s
steps = ["W 60", "S drive", "E", "W 30", "S ask", "T Y", "W 30", "S pw1", "T secret", "E", "W 20", "T secret", "E", "W 30", "S date", "T 20261114", "E", "W 120", "S cal"]
if __name__ == "__main__":
    d, p = s.run("d1", steps)
    s.sheet(p, s.ROOT / "work" / "sess" / "d1_sheet.png", cols=2)
    print(p)
