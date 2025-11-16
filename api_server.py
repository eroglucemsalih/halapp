from flask import Flask, request, jsonify, abort
from flask_cors import CORS
import sqlite3
from pathlib import Path
from math import radians, cos, sin, asin, sqrt
import json

BASE = Path(__file__).parent
DB_PATH = BASE / 'data' / 'hal_prices.sqlite'
MARKET_COORDS_FILE = BASE / 'backend' / 'market_coords.json'

app = Flask(__name__)
CORS(app)

# fallback coords if file not present
DEFAULT_MARKETS = [
    {"id": "gazipasa_market", "name": "Gazipaşa", "lat": 36.164, "lon": 32.314},
    {"id": "kumluca_market", "name": "Kumluca", "lat": 36.276, "lon": 30.426},
    {"id": "izmir_market", "name": "İzmir", "lat": 38.4237, "lon": 27.1428}
]


def load_markets():
    if MARKET_COORDS_FILE.exists():
        try:
            with open(MARKET_COORDS_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('markets', DEFAULT_MARKETS)
        except Exception:
            return DEFAULT_MARKETS
    return DEFAULT_MARKETS


def haversine(lat1, lon1, lat2, lon2):
    # convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    km = 6367 * c
    return km


@app.route('/api/markets')
def api_markets():
    markets = load_markets()
    return jsonify({'markets': markets})


@app.route('/api/market/<market_id>/latest')
def api_market_latest(market_id):
    if not DB_PATH.exists():
        return jsonify({'error': 'DB not found'}), 500
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute('SELECT * FROM prices WHERE market_id=? ORDER BY date_scraped DESC LIMIT 100', (market_id,))
    rows = cur.fetchall()
    conn.close()
    data = [dict(r) for r in rows]
    return jsonify({'market_id': market_id, 'data': data})


@app.route('/api/prices')
def api_prices():
    # support either market_id or lat/lon
    market_id = request.args.get('market_id')
    lat = request.args.get('lat')
    lon = request.args.get('lon')
    radius_km = float(request.args.get('radius_km', '50'))

    if not DB_PATH.exists():
        return jsonify({'error': 'DB not found'}), 500

    markets = load_markets()

    # if market_id provided, return that market latest
    if market_id:
        return api_market_latest(market_id)

    if lat and lon:
        try:
            latf = float(lat)
            lonf = float(lon)
        except ValueError:
            return jsonify({'error': 'invalid lat/lon'}), 400
        # find nearest markets within radius
        distances = []
        for m in markets:
            d = haversine(latf, lonf, float(m.get('lat', 0)), float(m.get('lon', 0)))
            distances.append((d, m))
        distances.sort(key=lambda x: x[0])
        nearby = [m for d, m in distances if d <= radius_km]
        if not nearby:
            # if none in radius return nearest (first)
            nearby = [distances[0][1]] if distances else []
        # collect latest data for each nearby market
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        result = []
        for m in nearby:
            cur.execute('SELECT * FROM prices WHERE market_id=? ORDER BY date_scraped DESC LIMIT 200', (m['id'],))
            rows = [dict(r) for r in cur.fetchall()]
            result.append({'market': m, 'data': rows})
        conn.close()
        return jsonify({'nearby': result})

    return jsonify({'error': 'provide market_id or lat & lon'}), 400


if __name__ == '__main__':
    print('Starting API server on http://0.0.0.0:5000')
    app.run(host='0.0.0.0', port=5000)
