"""KDIARY: write an entry (first line = title), save, back to the calendar; check the file and the '*' mark."""
import dsession as s
steps = ["W 60", "S drive", "E", "W 30", "S ask", "T Y", "W 30", "T secret", "E", "W 20", "T secret", "E", "W 30", "T 20261114", "E", "W 120",
         "E", "W 200", "S edit0",
         "T Today is good.", "E", "T Second line.", "W 20", "S edit1",
         "T <ES>", "T W", "E", "W 400", "S saved", "T <ES>Q", "E", "W 400", "S cal"]
if __name__ == "__main__":
    d, p = s.run("d2", steps)
    s.sheet(p, s.ROOT / "work" / "sess" / "d2_sheet.png", cols=2)
    print(s.acx("-l", d).stdout.decode("latin1"))
