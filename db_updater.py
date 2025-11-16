#!/usr/bin/env python3
"""
DB Updater and Daily Backup
- Runs configured scraper scripts periodically to refresh DB
- Ensures a UNIQUE constraint on (market_id, product, date_scraped)
- Daily at 04:00 creates `backups/YYYY-MM-DD/` and saves latest per-market Excel files named `marketid_YYYY-MM-DD.xlsx`

Usage:
- Run once: python db_updater.py --once
- Run as scheduler: python db_updater.py
- For immediate backup: python db_updater.py --backup-now
"""
import sqlite3
import subprocess
import sys
from pathlib import Path
import time
import pandas as pd
import os
import schedule
from datetime import datetime

BASE = Path(__file__).parent
# prefer main DB if exists, else fallback
MAIN_DB = BASE / 'data' / 'hal_prices.sqlite'
FALLBACK_DB = BASE / 'data' / 'hal_prices_three.sqlite'
DB_PATH = MAIN_DB if MAIN_DB.exists() else FALLBACK_DB
SCRIPTS = [
    (BASE / 'gazipasa veri.py', 'gazipasa_hal_fiyatlari.xlsx', 'gazipasa_market'),
    (BASE / 'kumluca veri.py', 'kumluca_hal_fiyatlari.xlsx', 'kumluca_market'),
    (BASE / 'veri çekme izmir.py', 'izmir_hal_fiyatlari.xlsx', 'izmir_market'),
]
BACKUP_DIR = BASE / 'backups'
# How often to refresh (minutes)
REFRESH_INTERVAL_MIN = 10

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
    inserted_at INTEGER,
    UNIQUE(market_id, product, date_scraped)
);
'''

EXPECTED_COLS = ['Ürün Adı', 'Kategori', 'En Düşük Fiyat (TL)', 'En Yüksek Fiyat (TL)', 'Birim']


def ensure_db():
    DB_PATH.parent.mkdir(exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(CREATE_TABLE_SQL)
    conn.commit()
    conn.close()


def run_script_once(script_path: Path):
    try:
        proc = subprocess.run([sys.executable, str(script_path), '--once'], capture_output=True, text=True, timeout=240)
        return proc.returncode, proc.stdout + "\n" + proc.stderr
    except Exception as e:
        return -1, str(e)


def read_excel_safe(path: Path):
    try:
        return pd.read_excel(path)
    except Exception:
        try:
            return pd.read_excel(path, engine='openpyxl')
        except Exception:
            return None


def normalize_df(df: pd.DataFrame):
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


def upsert_rows(conn, rows):
        cur = conn.cursor()
        # For portability, do a per-row upsert: try UPDATE, if no rows updated then INSERT
        update_sql = '''
        UPDATE prices SET
            market_name = ?,
            category = ?,
            price_min = ?,
            price_max = ?,
            unit = ?,
            source_file = ?,
            inserted_at = ?
        WHERE market_id = ? AND product = ? AND date_scraped = ?
        '''
        insert_sql = '''
        INSERT INTO prices (market_id, market_name, product, category, price_min, price_max, unit, date_scraped, source_file, inserted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        '''
        for r in rows:
                # r: (market_id, market_name, prod, cat, pmin, pmax, unit, scraped_date, source_file, inserted_at)
                market_id, market_name, prod, cat, pmin, pmax, unit, scraped_date, source_file, inserted_at = r
                cur.execute(update_sql, (market_name, cat, pmin, pmax, unit, source_file, inserted_at, market_id, prod, scraped_date))
                if cur.rowcount == 0:
                        cur.execute(insert_sql, (market_id, market_name, prod, cat, pmin, pmax, unit, scraped_date, source_file, inserted_at))
        conn.commit()


def refresh_from_scripts():
    print(f"[{datetime.now()}] Refresh started...")
    ensure_db()
    conn = sqlite3.connect(DB_PATH)
    summary = []
    for script_path, excel_name, market_id in SCRIPTS:
        print(f"Running {script_path.name} --once")
        rc, out = run_script_once(script_path)
        print(out)
        excel_path = BASE / excel_name
        if not excel_path.exists():
            print(f"Output missing for {script_path.name}: {excel_path}")
            summary.append((script_path.name, False, 'no output'))
            continue
        df = read_excel_safe(excel_path)
        if df is None:
            summary.append((script_path.name, False, 'read error'))
            continue
        df = normalize_df(df)
        rows = []
        scraped_date = datetime.now().strftime('%Y-%m-%d')
        market_name = market_id.replace('_', ' ').title()
        for _, r in df.iterrows():
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
        if rows:
            upsert_rows(conn, rows)
            print(f"Upserted {len(rows)} rows for {market_id}")
            summary.append((script_path.name, True, len(rows)))
        else:
            summary.append((script_path.name, False, 'no rows'))
    conn.close()
    print(f"[{datetime.now()}] Refresh finished. Summary: {summary}")
    return summary


def backup_now():
    ensure_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    today = datetime.now().strftime('%Y-%m-%d')
    target_folder = BACKUP_DIR / today
    target_folder.mkdir(parents=True, exist_ok=True)
    # determine markets from SCRIPTS
    for _, _, market_id in SCRIPTS:
        # try to select rows for today, else latest date
        cur.execute("SELECT date_scraped FROM prices WHERE market_id=? ORDER BY date_scraped DESC LIMIT 1", (market_id,))
        row = cur.fetchone()
        if not row:
            print(f"No data for {market_id}, skipping backup")
            continue
        date_to_use = row[0]
        # fetch rows for that date
        df = pd.read_sql_query("SELECT product as [Ürün Adı], category as [Kategori], price_min as [En Düşük Fiyat (TL)], price_max as [En Yüksek Fiyat (TL)], unit as [Birim] FROM prices WHERE market_id=? AND date_scraped=?", conn, params=(market_id, date_to_use))
        filename = f"{market_id}_{date_to_use}.xlsx"
        out_path = target_folder / filename
        try:
            df.to_excel(out_path, index=False, engine='openpyxl')
            print(f"Backed up {market_id} -> {out_path}")
        except Exception as e:
            print(f"Failed to write backup for {market_id}: {e}")
    conn.close()


def main_loop():
    # schedule refresh every REFRESH_INTERVAL_MIN minutes
    schedule.every(REFRESH_INTERVAL_MIN).minutes.do(refresh_from_scripts)
    # schedule daily backup at 16:00
    schedule.every().day.at("16:00").do(backup_now)
    print(f"Scheduler started. Refresh every {REFRESH_INTERVAL_MIN} minutes, backup daily at 04:00. DB: {DB_PATH}")
    # run an initial refresh
    refresh_from_scripts()
    while True:
        schedule.run_pending()
        time.sleep(10)

if __name__ == '__main__':
    if '--once' in sys.argv:
        refresh_from_scripts()
        sys.exit(0)
    if '--backup-now' in sys.argv:
        backup_now()
        sys.exit(0)
    main_loop()
