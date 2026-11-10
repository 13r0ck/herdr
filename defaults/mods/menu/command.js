// Only OSC 133 boundaries establish command ownership. Coordinates are [row, column].
const compare = (a, b) => a[0] - b[0] || a[1] - b[1];
export function commandAt(snapshot) {
  if (!snapshot || snapshot.alternate || !snapshot.clicked) return null;
  const { boundaries = [], rows = [], clicked } = snapshot;
  let start = null;
  let output = null;
  let end = null;
  for (const boundary of boundaries) {
    if (boundary.kind === 1 && boundary.prompt === 0) {
      if (start && output && boundary.at && compare(clicked, boundary.at) < 0) {
        end ??= boundary.at;
        break;
      }
      start = boundary.at;
      output = null;
      end = null;
    } else if (start && boundary.kind === 3) output = boundary.at;
    else if (start && boundary.kind === 4) {
      if (!boundary.at) return null;
      end = boundary.at;
    }
  }
  if (!start || !output || compare(clicked, start) < 0 || (end && compare(clicked, end) >= 0)) return null;
  let available = snapshot.cursor ?? [0, 0];
  for (let y = rows.length - 1; y >= output[0]; y--) {
    const used = rows[y].cells.filter(c => c.used);
    if (used.length) {
      const last = used[used.length - 1];
      const extent = [y, last.x + (last.width ?? 1)];
      if (compare(extent, available) > 0) available = extent;
      break;
    }
  }
  const limit = end ?? available;
  if (compare(clicked, limit) >= 0) return null;
  function text(from, to, input) {
    let result = '';
    for (let y = from[0]; y <= to[0] && y < rows.length; y++) {
      const row = rows[y];
      const cells = row.cells.filter(c => compare([y, c.x], from) >= 0 && compare([y, c.x], to) < 0);
      let last = cells.length;
      while (last && !cells[last - 1].used) last--;
      result += cells.slice(0, last).filter(c => !input || c.semantic === 1).map(c => c.text).join('');
      if (y < to[0] && !row.wraps) result += '\n';
    }
    return result;
  }
  // Execution is reported after Enter's CRLF. Exclude that separator from input.
  const command = text(start, output, true).replace(/\n$/, '');
  return { command, output: text(output, limit, false) };
}
