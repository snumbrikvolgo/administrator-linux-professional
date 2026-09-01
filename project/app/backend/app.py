import json
import logging
import os
from datetime import datetime, timezone

import psycopg2
from flask import Flask, jsonify, request

BACKEND = os.getenv("BACKEND_NAME", os.uname().nodename)
LOG_PATH = os.getenv("LOG_PATH", "/var/log/cms-backend/app.log")


class JsonFormatter(logging.Formatter):
    """One JSON object per line, so Logstash can parse it without grok."""

    def format(self, record):
        return json.dumps({
            "@timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "backend": BACKEND,
            "message": record.getMessage(),
        })


handler = logging.FileHandler(LOG_PATH)
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler, logging.StreamHandler()])

app = Flask(__name__)


def db():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "192.168.57.11"),
        dbname=os.getenv("DB_NAME", "cms"),
        user=os.getenv("DB_USER", "cms"),
        password=os.getenv("DB_PASSWORD", "cms_password"),
    )


@app.get("/api/health")
def health():
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT 1")
    app.logger.info("health ok backend=%s", BACKEND)
    return jsonify(status="ok", backend=BACKEND, database="ok")


@app.get("/api/whoami")
def whoami():
    app.logger.info("whoami backend=%s", BACKEND)
    return jsonify(backend=BACKEND)


@app.get("/api/articles")
def list_articles():
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, title, body, created_at FROM articles ORDER BY id DESC")
        rows = cur.fetchall()
    return jsonify([
        {"id": r[0], "title": r[1], "body": r[2], "created_at": r[3].isoformat()}
        for r in rows
    ])


@app.post("/api/articles")
def create_article():
    data = request.get_json(force=True)
    title = data.get("title", "").strip()
    body = data.get("body", "").strip()
    if not title or not body:
        return jsonify(error="title and body are required"), 400
    with db() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO articles(title, body) VALUES (%s, %s) RETURNING id",
            (title, body),
        )
        article_id = cur.fetchone()[0]
    app.logger.info("article created id=%s title=%s", article_id, title)
    return jsonify(id=article_id), 201


@app.delete("/api/articles/<int:article_id>")
def delete_article(article_id):
    with db() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM articles WHERE id = %s", (article_id,))
    app.logger.info("article deleted id=%s", article_id)
    return "", 204


@app.get("/api/demo-error")
def demo_error():
    app.logger.error("demo error requested")
    return jsonify(error="demo"), 500
