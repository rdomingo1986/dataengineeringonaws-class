"""
Gerador de dados de amostra "sujos" para a demo do data lake.

Produz eventos de estudantes em JSON Lines (um objeto por linha) com a mesma
"sujeira" realista dos lotes de exemplo: datas em formatos mistos, maiusculas/
minusculas inconsistentes, espacos, alguns nulos, numeros como texto, e uma
porcentagem de duplicatas e registros lixo (para que a limpeza do data lake
continue sendo demonstravel).

Parametrizavel pela quantidade de registros e pelo arquivo de saida. Os datasets
grandes gerados NAO sao versionados no repositorio (ver .gitignore); recrie-os
quando precisar com este script.

Uso:
    python generate_large_sample.py [opcoes]

Opcoes:
    -n, --num-events N      quantidade de eventos "base" a gerar (padrao: 1500)
    -o, --output ARQUIVO    caminho do arquivo de saida
                            (padrao: student-events-large.json)
    --seed S                semente aleatoria para reprodutibilidade (padrao: 42)
    --dup-pct P             porcentagem de duplicatas exatas (padrao: 0.02 = 2%)
    --junk-pct P            porcentagem de registros lixo (padrao: 0.01 = 1%)

Exemplos:
    # Dataset pequeno padrao
    python generate_large_sample.py

    # 200 mil eventos para testar desempenho
    python generate_large_sample.py -n 200000 -o student-events-200k.json

    # Reproduzivel com outra semente e mais ruido
    python generate_large_sample.py -n 5000 --seed 7 --dup-pct 0.05 --junk-pct 0.03
"""

import argparse
import json
import random

# --- Catalogos base -------------------------------------------------------
# (nomes/cursos em pt-BR de proposito: refletem o dominio de exemplo)
FIRST_NAMES = [
    "Ana", "Carlos", "Mariana", "João", "Fernanda", "Rafael", "Beatriz",
    "Lucas", "Juliana", "Pedro", "Camila", "Gustavo", "Larissa", "Felipe",
    "Patrícia", "Bruno", "Aline", "Rodrigo", "Vanessa", "Thiago",
]
LAST_NAMES = [
    "Souza", "Pereira", "Lima", "Mendes", "Alves", "Oliveira", "Costa",
    "Santos", "Rodrigues", "Ferreira", "Almeida", "Nascimento", "Carvalho",
]

# Cursos com grafias "sujas" (o pipeline as normaliza)
COURSES_DIRTY = [
    "python para dados", "Python para Dados", "PYTHON PARA DADOS",
    "fundamentos de aws", "Fundamentos de AWS", "FUNDAMENTOS DE AWS ",
    "sql avançado", "SQL AVANÇADO", "Sql Avançado",
    "machine learning", "Machine Learning", "MACHINE LEARNING",
    "engenharia de dados", "Engenharia de Dados",
    "visualização de dados", "Visualização de Dados",
]

EVENT_TYPES_DIRTY = [
    "login", "LOGIN", "Login",
    "lesson_completed", "LESSON_COMPLETED", "Lesson_Completed",
    "video_watched", "VIDEO_WATCHED",
    "quiz_submitted", "Quiz_Submitted", "QUIZ_SUBMITTED",
]

REGIONS_DIRTY = ["br-sp", "BR-SP", "br-rj", "BR-RJ", "BR-MG", "br-mg",
                 "BR-RS", "br-rs", "BR-PR", "BR-PR", "BR-BA", "br-ba"]

DEVICES = ["Mobile", "mobile", "Desktop", "desktop", "Tablet", "tablet"]


def dirty_date(y, m, d, hh, mm, ss):
    """Retorna a data em um de varios formatos (misturados de proposito)."""
    fmts = [
        f"{y:04d}-{m:02d}-{d:02d} {hh:02d}:{mm:02d}:{ss:02d}",
        f"{y:04d}-{m:02d}-{d:02d}T{hh:02d}:{mm:02d}:{ss:02d}Z",
        f"{d:02d}/{m:02d}/{y:04d} {hh:02d}:{mm:02d}",
        f"{y:04d}-{m:02d}-{d:02d}",
    ]
    return random.choice(fmts)


def make_student(i):
    sid = f"STU-{1000 + i}"
    fn = random.choice(FIRST_NAMES)
    ln = random.choice(LAST_NAMES)
    name = f"{fn} {ln}"
    # as vezes com espacos a mais / maiusculas estranhas
    if random.random() < 0.3:
        name = f"  {name} "
    email = f"{fn}.{ln}@example.com.br".lower()
    if random.random() < 0.2:
        email = email.upper()
    cpf = f"{random.randint(100,999)}.{random.randint(100,999)}.{random.randint(100,999)}-{random.randint(10,99)}"
    region = random.choice(REGIONS_DIRTY)
    return {"sid": sid, "name": name, "email": email, "cpf": cpf, "region": region}


def generate(num_events, out_path, dup_pct, junk_pct):
    """Gera os registros e escreve em JSON Lines no arquivo de saida."""
    n_students = max(20, num_events // 35)   # ~35 eventos por estudante
    students = [make_student(i) for i in range(n_students)]

    records = []
    for e in range(num_events):
        st = random.choice(students)
        y = 2026
        m = 3
        d = random.randint(1, 14)       # ~2 semanas
        hh = random.randint(6, 22)
        mm = random.randint(0, 59)
        ss = random.randint(0, 59)
        etype = random.choice(EVENT_TYPES_DIRTY)
        is_quiz = "quiz" in etype.lower()

        duration = str(random.choice([0, 180, 300, 480, 620, 900, 1260, 1500]))
        if random.random() < 0.03:      # 3% duracao invalida
            duration = "a"

        score = None
        if is_quiz:
            score = str(round(random.uniform(5.0, 10.0), 1))

        rec = {
            "event_id": f"evt-{e:05d}",
            "student_id": st["sid"],
            "student_name": st["name"],
            "student_email": st["email"] if random.random() > 0.05 else None,
            "cpf": st["cpf"],
            "course": random.choice(COURSES_DIRTY),
            "event_type": etype,
            "event_ts": dirty_date(y, m, d, hh, mm, ss),
            "duration_seconds": duration,
            "score": score,
            "region": st["region"],
            "device": random.choice(DEVICES),
        }
        records.append(rec)

    # Injetar duplicatas exatas
    n_dups = max(1, int(num_events * dup_pct)) if dup_pct > 0 else 0
    for _ in range(n_dups):
        records.append(dict(random.choice(records)))

    # Injetar registros lixo (sem student_id ou data invalida)
    n_junk = max(1, int(num_events * junk_pct)) if junk_pct > 0 else 0
    for j in range(n_junk):
        records.append({
            "event_id": f"evt-junk-{j}",
            "student_id": None,
            "student_name": "   ",
            "student_email": "ghost@example.com.br",
            "cpf": None,
            "course": None,
            "event_type": "LESSON_COMPLETED",
            "event_ts": "not-a-date",
            "duration_seconds": None,
            "score": None,
            "region": None,
            "device": None,
        })

    random.shuffle(records)

    with open(out_path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"Gerados {len(records)} registros ({n_dups} duplicatas, {n_junk} lixo) em {out_path}")
    print(f"Estudantes unicos: {len(students)}")


def main():
    parser = argparse.ArgumentParser(
        description="Gera dados de amostra 'sujos' (JSON Lines) para a demo do data lake."
    )
    parser.add_argument("-n", "--num-events", type=int, default=1500,
                        help="quantidade de eventos base a gerar (padrao: 1500)")
    parser.add_argument("-o", "--output", default="student-events-large.json",
                        help="arquivo de saida (padrao: student-events-large.json)")
    parser.add_argument("--seed", type=int, default=42,
                        help="semente aleatoria para reprodutibilidade (padrao: 42)")
    parser.add_argument("--dup-pct", type=float, default=0.02,
                        help="porcentagem de duplicatas exatas (padrao: 0.02)")
    parser.add_argument("--junk-pct", type=float, default=0.01,
                        help="porcentagem de registros lixo (padrao: 0.01)")
    args = parser.parse_args()

    if args.num_events <= 0:
        parser.error("--num-events deve ser maior que zero.")

    random.seed(args.seed)
    generate(args.num_events, args.output, args.dup_pct, args.junk_pct)


if __name__ == "__main__":
    main()
