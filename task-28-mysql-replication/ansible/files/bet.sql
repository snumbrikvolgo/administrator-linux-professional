CREATE DATABASE IF NOT EXISTS bet;
USE bet;

DROP TABLE IF EXISTS events_on_demand;
DROP TABLE IF EXISTS v_same_event;
DROP TABLE IF EXISTS odds;
DROP TABLE IF EXISTS outcome;
DROP TABLE IF EXISTS market;
DROP TABLE IF EXISTS competition;
DROP TABLE IF EXISTS bookmaker;

CREATE TABLE bookmaker (
  id INT NOT NULL PRIMARY KEY,
  bookmaker_name VARCHAR(64) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE competition (
  id INT NOT NULL PRIMARY KEY,
  competition_name VARCHAR(128) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE market (
  id INT NOT NULL PRIMARY KEY,
  market_name VARCHAR(128) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE outcome (
  id INT NOT NULL PRIMARY KEY,
  outcome_name VARCHAR(128) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE odds (
  id INT NOT NULL PRIMARY KEY,
  bookmaker_id INT NOT NULL,
  market_id INT NOT NULL,
  outcome_id INT NOT NULL,
  odd_value DECIMAL(5,2) NOT NULL,
  KEY bookmaker_id (bookmaker_id),
  KEY market_id (market_id),
  KEY outcome_id (outcome_id)
) ENGINE=InnoDB;

CREATE TABLE events_on_demand (
  id INT NOT NULL PRIMARY KEY,
  event_name VARCHAR(128) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE v_same_event (
  id INT NOT NULL PRIMARY KEY,
  source_event VARCHAR(128) NOT NULL
) ENGINE=InnoDB;

INSERT INTO bookmaker (id, bookmaker_name) VALUES
  (3, 'unibet'),
  (4, 'betway'),
  (5, 'bwin'),
  (6, 'ladbrokes');

INSERT INTO competition (id, competition_name) VALUES (1, 'Premier League');
INSERT INTO market (id, market_name) VALUES (1, 'Winner');
INSERT INTO outcome (id, outcome_name) VALUES (1, 'Home');
INSERT INTO odds (id, bookmaker_id, market_id, outcome_id, odd_value) VALUES (1, 4, 1, 1, 1.95);
INSERT INTO events_on_demand (id, event_name) VALUES (1, 'Ignored live event');
INSERT INTO v_same_event (id, source_event) VALUES (1, 'Ignored duplicate event');
