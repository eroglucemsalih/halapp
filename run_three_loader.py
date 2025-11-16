#!/usr/bin/env python3
import importlib.util
import sys
from pathlib import Path
import time
import pandas as pd
import sqlite3
import os
import traceback

BASE = Path(__file__).parent
SCRIPTS = [
    (BASE / 'gazipasa veri.py', 'gazipasa_hal_fiyatlari.xlsx', 'gazipasa_market'),
    (BASE / 'kumluca veri.py', 'kumluca_hal_fiyatlari.xlsx', 'kumluca_market'),
    (BASE / 'veri çekme izmir.py', 'izmir_hal_fiyatlari.xlsx', 'izmir_market'),
]
DB_PATH = BASE / 'data' / 'hal_prices_three.sqlite'
DB_PATH.parent.mkdir(exist_ok=True)

# remove existing DB to start fresh
if DB_PATH.exists():
    print(f"Removing existing DB: {DB_PATH}")
    DB_PATH.unlink()

CREATE_TABLE_SQL = '''
CREATE TABLE IF NOT EXISTS prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    market_id TEXT,
    market_name TEXT,
    product TEXT,
    category TEXT,
    price_min REAL,
    price_max REAL,
    unit TEXT,
    date_scraped TEXT,
    source_file TEXT,
    inserted_at INTEGER
);
'''

EXPECTED_COLS = ['Ürün Adı', 'Kategori', 'En Düşük Fiyat (TL)', 'En Yüksek Fiyat (TL)', 'Birim']


def read_excel_safe(path):
    try:
        return pd.read_excel(path)
    except Exception:
        try:
            return pd.read_excel(path, engine='openpyxl')
        except Exception:
            return None


def normalize_df(df):
    cols = list(df.columns)
    mapping = {}
    for target in EXPECTED_COLS:
        lt = target.lower()
        for c in cols:
            if lt == c.lower() or lt in c.lower() or c.lower() in lt:
                mapping[c] = target
                break
    df = df.rename(columns=mapping)
    for c in EXPECTED_COLS:
        if c not in df.columns:
            df[c] = None
    return df[EXPECTED_COLS]


def insert_into_db(conn, rows):
    cur = conn.cursor()
    cur.executemany('''
        INSERT INTO prices (market_id, market_name, product, category, price_min, price_max, unit, date_scraped, source_file, inserted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', rows)
    conn.commit()


def load_module_and_run(path: Path):
    name = path.stem.replace(' ', '_')
    spec = importlib.util.spec_from_file_location(name, str(path))
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as e:
        print(f"Failed to exec module {path.name}: {e}")
        return None
    # prefer calling verileri_cek_ve_kaydet() if exists
    if hasattr(module, 'verileri_cek_ve_kaydet'):
        try:
            res = module.verileri_cek_ve_kaydet()
            return res
        except Exception as e:
            print(f"Error running verileri_cek_ve_kaydet in {path.name}: {e}")
            return None
    else:
        print(f"Module {path.name} has no verileri_cek_ve_kaydet(); skipping import-run")
        return None


def main():
    conn = sqlite3.connect(DB_PATH)
    conn.execute(CREATE_TABLE_SQL)
    conn.commit()

    summary = []
    for script_path, excel_name, market_id in SCRIPTS:
        print(f"== Loading module: {script_path.name}")
        try:
            df_returned = load_module_and_run(script_path)
        except Exception as e:
            print('Module load/run failed:', e)
            df_returned = None
        time.sleep(1)
        excel_path = BASE / excel_name
        if not excel_path.exists():
            print(f"Warning: expected output not found: {excel_path}")
            summary.append((script_path.name, False, 'no output file'))
            continue
        df = read_excel_safe(excel_path)
        if df is None:
            print(f"Error: {excel_path} could not be read or is empty")
            summary.append((script_path.name, False, 'read error'))
            continue
        df = normalize_df(df)
        rows = []
        scraped_date = time.strftime('%Y-%m-%d %H:%M:%S')
        market_name = market_id.replace('_', ' ').title()
        for _, r in df.iterrows():
            try:
                def to_float(v):
                    if v is None: return None
                    s = str(v).replace('₺','').replace(',','.')
                    try:
                        return float(s)
                    except:
                        return None
                pmin = to_float(r.get('En Düşük Fiyat (TL)'))
                pmax = to_float(r.get('En Yüksek Fiyat (TL)'))
                unit = r.get('Birim') if pd.notna(r.get('Birim')) else None
                prod = r.get('Ürün Adı')
                cat = r.get('Kategori') if pd.notna(r.get('Kategori')) else None
                rows.append((market_id, market_name, prod, cat, pmin, pmax, unit, scraped_date, str(excel_path.name), int(time.time())))
            except Exception:
                print('Row processing error:', traceback.format_exc())
        if rows:
            insert_into_db(conn, rows)
            print(f"{len(rows)} rows inserted into DB from {excel_path.name}")
            summary.append((script_path.name, True, f'{len(rows)} rows'))
        else:
            summary.append((script_path.name, False, 'no rows'))

    print('\n== Summary ==')
    for item in summary:
        print(item)
    conn.close()

if __name__ == '__main__':
    main()
