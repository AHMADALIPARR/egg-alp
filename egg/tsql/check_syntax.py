"""Syntax-only check of schema.sql with sqlglot (dialect tsql). Does NOT execute anything and does NOT prove the schema works on SQL Server."""
import re, sys, sqlglot
src = open(sys.argv[1] if len(sys.argv) > 1 else "tsql/schema.sql").read()
batches = [b.strip() for b in re.split(r"^GO\s*$", src, flags=re.M) if b.strip()]
ok = 0; bad = 0
for b in batches:
    try:
        sqlglot.parse(b, read="tsql"); ok += 1
    except Exception as e:
        bad += 1; print("SYNTAX-ERROR:", str(e).splitlines()[0], "|", b[:70].replace("\n", " "))
print(f"tsql syntax-only (sqlglot {sqlglot.__version__}): {ok} batches parsed, {bad} failed; NOT executed on SQL Server")
sys.exit(1 if bad else 0)
