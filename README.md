# Функціональне програмування — варіант 3

**Левківський Євгеній Сергійович · ІПС-41**

Виконано **третє завдання в кожній із трьох лабораторних**.

| Робота | Завдання | Звіт |
| --- | --- | --- |
| [lab1](lab1) | Програмне забезпечення на мережі факультету; Haskell, MySQL, classes / instances | [PDF](lab1/report.pdf) · [DOCX](lab1/report.docx) |
| [lab2](lab2) | Паралельний метод Гаусса для систем лінійних рівнянь | [PDF](lab2/report.pdf) · [DOCX](lab2/report.docx) |
| [lab3](lab3) | Слово першого речення, якого немає в жодному іншому | [PDF](lab3/report.pdf) · [DOCX](lab3/report.docx) |

## Підготовлений комп’ютер Windows

```powershell
node scripts/local.mjs demo
node scripts/local.mjs lab1 search GHC
.\.build\lab2.exe solve 4 lab2/examples/system.txt +RTS -N4 -RTS
.\.build\lab3.exe lab3/examples/textbook.txt
node scripts/local.mjs verify
node scripts/benchmark.mjs
```

GHC 9.6.7, MySQL 8.4.6 та скомпільовані програми вже підготовлені локально. Потрібен Node.js 22.13+. Сценарій `local.mjs` запускає MySQL на `127.0.0.1:3307`, створює базу `faculty_software` та завантажує демонстраційні дані. Для зупинки: `node scripts/local.mjs stop`.

## Чистий комп’ютер Windows

Потрібні Windows x64, Node.js 22.13+, інтернет і приблизно 4 ГіБ вільного місця. Рекомендований шлях без кирилиці: `C:\Projects\functional-programming-ips41`.

```powershell
git clone https://github.com/fffooocus/functional-programming-ips41.git
cd functional-programming-ips41
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-windows.ps1
node scripts/local.mjs demo
```

Завантажуються офіційні переносимі GHC та MySQL у `.tools`; перевіряється SHA256 GHC, збираються програми та виконуються тести. Системні служби й глобальні налаштування не потрібні. Локальна демонстраційна база використовує `root` без пароля на інтерфейсі loopback; облікові дані Docker окремо наведені в `compose.yaml`.

## Docker

```sh
docker compose build
docker compose run --rm labs .build/lab1-run list
docker compose run --rm labs .build/lab1-run stats
docker compose run --rm labs .build/lab2-run solve 4 lab2/examples/system.txt +RTS -N4 -RTS
docker compose run --rm labs .build/lab3-run lab3/examples/textbook.txt
docker compose down
```

Образ під час складання виконує тести. MySQL 8.4 має 11 таблиць та представлення статистики; дані зберігаються в іменованому томі. Конфігурацію Docker підготовлено; фактичні перевірки виконано нативно на Windows.

## Збирання Haskell

Зовнішні пакети Hackage не потрібні: використано бібліотеки, що постачаються з GHC.

```sh
bash scripts/build.sh
.build/lab2-run solve 4 lab2/examples/system.txt +RTS -N4 -RTS
```

Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1`. Також є Cabal: `cabal build all`, `cabal test`, `cabal run lab3 -- lab3/examples/textbook.txt`.

Для окремого сервера MySQL виконайте SQL-файли `lab1/sql/01-schema.sql` та `02-seed.sql`, налаштуйте `MYSQL_BIN`, `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PWD`, `MYSQL_DATABASE=faculty_software`. Користувачеві потрібні права на цю БД. Docker створює користувача `department` автоматично; сценарій локального запуску налаштовує підготовлений сервер сам.

## Перевірки

- **44 автоматичні тести**: метод Гаусса, перестановки рядків, вироджені системи, масштабування, пул потоків, Unicode та валідація ПО.
- Інтеграція зі справжнім MySQL: версії, пошук, створення, оновлення, автори, дистрибутиви, доступ та статистика.
- Послідовне й паралельне рішення прикладу: **x = (2, 3, -1)**, максимальна нев’язка **0**.
- Аналіз прикладу підручника: **«функціональна»**; усі допустимі слова — «функціональна», «програмування».

[Журнали](verification), [параметри системи](verification/environment.json), [вимірювання](lab2/benchmark.csv).

| Потоки | Медіана, с | Прискорення | Ефективність |
| --- | --- | --- | --- |
| 1 | 0.340895 | 1.0000 | 1.0000 |
| 2 | 0.273305 | 1.2473 | 0.6237 |
| 4 | 0.362693 | 0.9399 | 0.2350 |

Метод Гаусса, N=384, три повторення, Ryzen 5 5600H, 12 логічних процесорів, GHC 9.6.7, `-O2 -threaded`. На цій матриці два працівники швидші за одного; для чотирьох витрати синхронізації переважають виграш. Після кожного запуску перевірено відоме рішення та нев’язку. Числа залежать від системи й навантаження.

## Комплект для здачі

У кожній папці: код `src` і `app`, інструкція та звіти `report.md`, `report.docx`, `report.pdf`. Додано SQL, матриці-приклади, навчальний текст, фактичні результати, [пояснення для захисту](DEFENSE.md) та вихідні умови в `assignments`.

[Реліз v1.0.0](https://github.com/fffooocus/functional-programming-ips41/releases/tag/v1.0.0) містить `submission.zip` з усім комплектом і Windows x64 програмами в `.build`. Для першої роботи потрібен MySQL; його завантажує `setup-windows.ps1`. Відтворення архіву: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/package.ps1`.

Програми консольні; вебхостинг не потрібний.

## Відтворення звітів

На Windows із системними Times New Roman та Consolas:

```powershell
npm.cmd install --prefix .tools --no-audit --no-fund docx@9.5.1 pdfkit@0.17.2 @napi-rs/canvas@0.1.80 pdfjs-dist@5.4.296
node scripts/reports.mjs
node scripts/check-reports.mjs
```

Перевірка контролює Unicode, ПІБ і групу, порожні сторінки та праве поле PDF. Мініатюри зберігаються в `.tools/previews`.
