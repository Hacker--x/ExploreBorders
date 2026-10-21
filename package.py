"""Create the standalone install ZIP from the repository's addon files."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import re

root = Path(__file__).resolve().parent
toc = (root / 'ExploreBorders.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version: (.+)$', toc, re.M).group(1).strip()
files = ['ExploreBorders.toc', 'README.txt', 'COVERAGE.txt', 'SOURCES.txt']
files += [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
output = root / 'dist' / ('ExploreBorders-' + version + '.zip')
output.parent.mkdir(exist_ok=True)
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / name, 'ExploreBorders/' + name)
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert all(name.startswith('ExploreBorders/') for name in archive.namelist())
print(output)
