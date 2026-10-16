CREATE DATABASE IF NOT EXISTS department_resources CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE department_resources;

CREATE TABLE IF NOT EXISTS authors (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS resource_types (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS purposes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(150) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS usage_terms (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(150) NOT NULL UNIQUE,
  conditions_text TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS resources (
  id INT PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(250) NOT NULL,
  annotation TEXT NOT NULL,
  type_id INT NOT NULL,
  terms_id INT NOT NULL,
  available_from DATE NOT NULL,
  expires_on DATE NULL,
  CONSTRAINT fk_resource_type FOREIGN KEY(type_id) REFERENCES resource_types(id),
  CONSTRAINT fk_resource_terms FOREIGN KEY(terms_id) REFERENCES usage_terms(id),
  CONSTRAINT valid_period CHECK(expires_on IS NULL OR expires_on >= available_from),
  INDEX idx_title(title)
);
CREATE TABLE IF NOT EXISTS resource_authors (
  resource_id INT NOT NULL,
  author_id INT NOT NULL,
  PRIMARY KEY(resource_id, author_id),
  FOREIGN KEY(resource_id) REFERENCES resources(id) ON DELETE CASCADE,
  FOREIGN KEY(author_id) REFERENCES authors(id)
);
CREATE TABLE IF NOT EXISTS resource_purposes (
  resource_id INT NOT NULL,
  purpose_id INT NOT NULL,
  PRIMARY KEY(resource_id, purpose_id),
  FOREIGN KEY(resource_id) REFERENCES resources(id) ON DELETE CASCADE,
  FOREIGN KEY(purpose_id) REFERENCES purposes(id)
);
CREATE TABLE IF NOT EXISTS resource_urls (
  id INT PRIMARY KEY AUTO_INCREMENT,
  resource_id INT NOT NULL,
  url VARCHAR(1000) NOT NULL,
  FOREIGN KEY(resource_id) REFERENCES resources(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  display_name VARCHAR(200) NOT NULL,
  group_name VARCHAR(50) NOT NULL,
  login VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS access_grants (
  resource_id INT NOT NULL,
  user_id INT NOT NULL,
  granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(resource_id,user_id),
  FOREIGN KEY(resource_id) REFERENCES resources(id) ON DELETE CASCADE,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS usage_events (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  resource_id INT NOT NULL,
  user_id INT NOT NULL,
  used_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  duration_seconds INT UNSIGNED NOT NULL,
  FOREIGN KEY(resource_id,user_id) REFERENCES access_grants(resource_id,user_id) ON DELETE CASCADE,
  INDEX idx_usage_resource_time(resource_id,used_at)
);

CREATE OR REPLACE VIEW resource_statistics AS
SELECT r.id, r.title, COUNT(e.id) AS visits,
       COUNT(DISTINCT e.user_id) AS unique_users,
       COALESCE(SUM(e.duration_seconds),0) AS total_seconds
FROM resources r LEFT JOIN usage_events e ON e.resource_id=r.id
GROUP BY r.id,r.title;
