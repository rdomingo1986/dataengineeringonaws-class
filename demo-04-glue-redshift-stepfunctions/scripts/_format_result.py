"""
Formata a saida de redshift-data get-statement-result (JSON) como uma tabela
legivel: cabecalhos + uma linha por registro, colunas separadas por ' | '.

Uso: python _format_result.py <caminho_json>
"""
import json
import sys


def cell(c):
    # Cada celula e um dict com uma unica chave de valor (ou isNull).
    if c.get("isNull"):
        return "NULL"
    for k in ("stringValue", "longValue", "doubleValue", "booleanValue"):
        if k in c:
            return str(c[k])
    return ""


def _read_json(path):
    # O redirect do cmd pode escrever em cp1252/latin-1, nao utf-8.
    # Testamos varias codificacoes para ler sem falhar.
    raw = open(path, "rb").read()
    for enc in ("utf-8", "utf-8-sig", "cp1252", "latin-1"):
        try:
            return json.loads(raw.decode(enc))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
    # ultimo recurso: ignorar bytes problematicos
    return json.loads(raw.decode("utf-8", errors="replace"))


def main():
    data = _read_json(sys.argv[1])

    cols = [c.get("name", "") for c in data.get("ColumnMetadata", [])]
    records = data.get("Records", [])

    if cols:
        print(" | ".join(cols))
        print("-" * (len(" | ".join(cols))))
    for row in records:
        print(" | ".join(cell(c) for c in row))
    print(f"\n({len(records)} linha(s))")


if __name__ == "__main__":
    main()
