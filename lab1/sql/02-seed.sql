USE department_resources;
INSERT IGNORE INTO authors(id,name) VALUES (1,'Haskell.org'),(2,'Oracle'),(3,'Левківський Євгеній Сергійович');
INSERT IGNORE INTO resource_types(id,name) VALUES (1,'Документація'),(2,'Навчальний посібник'),(3,'Приклад програми');
INSERT IGNORE INTO purposes(id,name) VALUES (1,'Самостійне навчання'),(2,'Лабораторні роботи'),(3,'Довідкова інформація');
INSERT IGNORE INTO usage_terms(id,name,conditions_text) VALUES
 (1,'Відкритий доступ','Ознайомлення за посиланням; поширення відповідно до ліцензії власника.'),
 (2,'Навчальне використання','Використання для виконання лабораторних робіт.');
INSERT IGNORE INTO resources(id,title,annotation,type_id,terms_id,available_from,expires_on) VALUES
 (1,'Haskell: GHC User Guide','Типи, класи типів, компіляція та паралельне виконання програм.',1,1,'2026-09-01',NULL),
 (2,'MySQL 8.4 Reference Manual','Реляційна модель, SQL, індекси, транзакції та зовнішні ключі.',1,1,'2026-09-01',NULL),
 (3,'Приклади функціонального програмування','Приклади чистих функцій та обробки тексту на Haskell.',3,2,'2026-09-01','2027-06-30');
INSERT IGNORE INTO resource_authors VALUES (1,1),(2,2),(3,3);
INSERT IGNORE INTO resource_purposes VALUES (1,1),(1,2),(2,2),(2,3),(3,2);
INSERT IGNORE INTO resource_urls(id,resource_id,url) VALUES
 (1,1,'https://downloads.haskell.org/ghc/9.6.7/docs/users_guide/'),
 (2,2,'https://dev.mysql.com/doc/refman/8.4/en/'),
 (3,3,'../lab3/examples/textbook.txt');
INSERT IGNORE INTO users(id,display_name,group_name,login) VALUES
 (1,'Левківський Євгеній Сергійович','ІПС-41','student');
INSERT IGNORE INTO access_grants(resource_id,user_id) VALUES (1,1),(2,1),(3,1);
INSERT IGNORE INTO usage_events(id,resource_id,user_id,used_at,duration_seconds) VALUES
 (1,1,1,'2026-10-01 10:00:00',300),(2,1,1,'2026-10-02 10:00:00',180),(3,2,1,'2026-10-03 11:00:00',240);
