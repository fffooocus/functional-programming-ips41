USE faculty_software;
INSERT IGNORE INTO authors(id,name) VALUES (1,'Haskell.org'),(2,'Oracle'),(3,'Левківський Євгеній Сергійович');
INSERT IGNORE INTO resource_types(id,name) VALUES (1,'Компілятор'),(2,'Система керування базами даних'),(3,'Навчальна програма');
INSERT IGNORE INTO purposes(id,name) VALUES (1,'Самостійне навчання'),(2,'Лабораторні роботи'),(3,'Довідкова інформація');
INSERT IGNORE INTO usage_terms(id,name,conditions_text) VALUES
 (1,'Відкритий доступ','Ознайомлення за посиланням; поширення відповідно до ліцензії власника.'),
 (2,'Навчальне використання','Використання для виконання лабораторних робіт.');
INSERT IGNORE INTO resources(id,title,version,annotation,type_id,terms_id,available_from,expires_on) VALUES
 (1,'GHC','9.6.7','Компілятор Haskell із підтримкою багатопотокового виконання.',1,1,'2026-09-01',NULL),
 (2,'MySQL Community Server','8.4.6','Сервер реляційної БД для лабораторних робіт факультету.',2,1,'2026-09-01',NULL),
 (3,'Навчальний аналізатор тексту','1.0.0','Програма обробки українського тексту на Haskell.',3,2,'2026-09-01','2027-06-30');
INSERT IGNORE INTO resource_authors VALUES (1,1),(2,2),(3,3);
INSERT IGNORE INTO resource_purposes VALUES (1,1),(1,2),(2,2),(2,3),(3,2);
INSERT IGNORE INTO resource_urls(id,resource_id,url) VALUES
 (1,1,'https://downloads.haskell.org/ghc/9.6.7/ghc-9.6.7-x86_64-unknown-mingw32.tar.xz'),
 (2,2,'https://cdn.mysql.com/archives/mysql-8.4/mysql-8.4.6-winx64.zip'),
 (3,3,'.build/lab3.exe');
INSERT IGNORE INTO users(id,display_name,group_name,login) VALUES
 (1,'Левківський Євгеній Сергійович','ІПС-41','student');
INSERT IGNORE INTO access_grants(resource_id,user_id) VALUES (1,1),(2,1),(3,1);
INSERT IGNORE INTO usage_events(id,resource_id,user_id,used_at,duration_seconds) VALUES
 (1,1,1,'2026-10-01 10:00:00',300),(2,1,1,'2026-10-02 10:00:00',180),(3,2,1,'2026-10-03 11:00:00',240);
