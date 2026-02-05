#!/usr/bin/python3

"""
This is the standard runscript for all of calibre's tools.
Do not modify it unless you know what you are doing.
"""

import sys, os, sqlite3, json

query: str = """
select
    B.title, A.authors, B.path, D.format, D.name as "filename", B.has_cover
from books B
join data D on D.book=B.id
left join (
    select
        BA.book,
        group_concat(A.name, ', ') as "authors"
    from books_authors_link BA
    join authors A on A.id=BA.author
    group by BA.book
) A on A.book=B.id
;
"""

def main():
    path = os.environ.get('CALIBRE_PYTHON_PATH', '/usr/lib/calibre')
    if path not in sys.path:
        sys.path.insert(0, path)

    sys.resources_location = os.environ.get('CALIBRE_RESOURCES_PATH', '/usr/share/calibre')
    sys.extensions_location = os.environ.get('CALIBRE_EXTENSIONS_PATH', '/usr/lib/calibre/calibre/plugins')
    sys.executables_location = os.environ.get('CALIBRE_EXECUTABLES_PATH', '/usr/bin')
    sys.system_plugins_location = None

    c = Context()
    c.dump_db()

class Context():
    def __init__(self):
        from calibre.utils.config import prefs

        self.library_path = prefs['library_path']

    def dump_db(self):
        with sqlite3.connect(os.path.join(self.library_path, 'metadata.db')) as conn:
            conn.row_factory = lambda cur, row: self.row_factory(cur, row)
            cur = conn.execute(query)
            all_data = cur.fetchall()
            print(json.dumps(all_data))

    def row_factory(self, cur: sqlite3.Cursor, row: Tuple) -> Dict:
        return {
            'title': row[0],
            'authors': fix_authors(row[1]),
            'file': os.path.join(self.library_path, row[2], row[4] + '.' + row[3].lower()),
            'format': row[3],
            'cover': os.path.join(self.library_path, row[2], 'cover.jpg') if row[5] == 1 else None,
        }

def fix_authors(piped: str) -> str:
    #                                                                1. Split the authors by ', '
    #                2. Iterate over the authors
    #                                                3. Split each author by '| '
    #                                       4. Reverse the order of the author parts
    #                              5. Join the author parts with a space
    #      6. Join the authors with a comma and space
    return ', '.join(map(lambda a: ' '.join(reversed(a.split('| '))), piped.split(', ')))

if __name__ == "__main__":
    main()
