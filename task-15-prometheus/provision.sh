#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_VERSION="2.54.1"
NODE_EXPORTER_VERSION="1.8.2"
GRAFANA_DEB="grafana_11.1.4_amd64.deb"
GRAFANA_URL="https://dl.grafana.com/oss/release/${GRAFANA_DEB}"
CONFIG_DIR="/tmp"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl wget tar adduser libfontconfig1 musl jq

id -u prometheus >/dev/null 2>&1 || useradd --no-create-home --shell /usr/sbin/nologin prometheus
id -u node_exporter >/dev/null 2>&1 || useradd --no-create-home --shell /usr/sbin/nologin node_exporter

mkdir -p /etc/prometheus /var/lib/prometheus

cd /tmp
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
tar -xzf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
cp "prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus" /usr/local/bin/
cp "prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool" /usr/local/bin/
cp -r "prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles" /etc/prometheus/
cp -r "prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries" /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar -xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

wget -q "${GRAFANA_URL}"
dpkg -i "${GRAFANA_DEB}" || apt-get install -f -y

install -m 0644 "${CONFIG_DIR}/prometheus.yml" /etc/prometheus/prometheus.yml
install -m 0644 "${CONFIG_DIR}/prometheus.service" /etc/systemd/system/prometheus.service
install -m 0644 "${CONFIG_DIR}/node_exporter.service" /etc/systemd/system/node_exporter.service

systemctl daemon-reload
systemctl enable --now node_exporter
systemctl enable --now prometheus
systemctl enable --now grafana-server
