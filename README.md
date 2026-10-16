# Функціональне програмування

**Левківський Євгеній Сергійович · ІПС-41**

Три лабораторні роботи на Haskell в одному репозиторії. У кожному документі обрано перше завдання; окремого номера варіанта не задано.

| Робота | Завдання | Звіт |
| --- | --- | --- |
| [lab1](lab1) | Інформаційні ресурси кафедри, MySQL, classes / instances | [PDF](lab1/report.pdf) · [DOCX](lab1/report.docx) |
| [lab2](lab2) | Багатопотоковий архіватор Хаффмана, вимірювання прискорення | [PDF](lab2/report.pdf) · [DOCX](lab2/report.docx) |
| [lab3](lab3) | Найбільша кількість речень зі спільним словом | [PDF](lab3/report.pdf) · [DOCX](lab3/report.docx) |

## Запуск на підготовленому комп’ютері Windows

Потрібен Node.js 22.13+; GHC 9.6.7, MySQL 8.4.6 та скомпільовані програми вже підготовлені локально.

```powershell
node scripts/local.mjs demo
node scripts/local.mjs lab1 search Haskell
node scripts/local.mjs verify
node scripts/benchmark.mjs
```

`local.mjs` запускає MySQL лише на `127.0.0.1:3307`, завантажує схему й демонстраційні дані без повторного створення наявних записів. Для зупинки: `node scripts/local.mjs stop`.

## Чистий комп’ютер Windows

Потрібні Windows x64, Node.js 22.13+, доступ до інтернету та приблизно 4 ГіБ вільного місця. Рекомендований шлях клонування без кирилиці: `C:\Projects\functional-programming-ips41`.

```powershell
git clone https://github.com/fffooocus/functional-programming-ips41.git
cd functional-programming-ips41
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-windows.ps1
node scripts/local.mjs demo
```

Сценарій завантажує переносимі офіційні GHC і MySQL у `.tools`, перевіряє SHA256 GHC, збирає програми та запускає тести. Системні служби й глобальні налаштування не потрібні. Локальна демонстраційна база використовує `root` без пароля на інтерфейсі loopback; параметри Docker наведені окремо в `compose.yaml`.

## Запуск через Docker

```sh
docker compose build
docker compose run --rm labs .build/lab1-run list
docker compose run --rm labs .build/lab1-run search Haskell
docker compose run --rm labs .build/lab1-run stats
docker compose run --rm labs .build/lab3-run lab3/examples/textbook.txt
docker compose run --rm labs .build/lab2-run pack 4 lab2/demo.hfar lab3/examples/textbook.txt +RTS -N4 -RTS
docker compose run --rm labs .build/lab2-run unpack lab2/demo.hfar lab2/restored
docker compose down
```

Під час складання образу автоматично виконуються тести. Контейнер MySQL 8.4 має 11 таблиць і представлення статистики; дані зберігаються в іменованому томі. Конфігурація Docker підготовлена; фактичні перевірки виконано нативно на Windows.

## Haskell без Docker

Зовнішні бібліотеки Hackage не потрібні: використано пакети, що постачаються з GHC. Потрібен GHC 9.6.7 або сумісний, а для першої роботи — MySQL Server та клієнт `mysql`.

```sh
bash scripts/build.sh
.build/lab3-run lab3/examples/textbook.txt
```

Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1`.

Також є `functional-labs.cabal`: `cabal build all`, `cabal test`, `cabal run lab3 -- lab3/examples/textbook.txt`.

Для зовнішньої MySQL встановіть `MYSQL_BIN`, `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PWD`, `MYSQL_DATABASE`. Виконайте `lab1/sql/01-schema.sql` та `02-seed.sql`. Приклад Linux:

```sh
mysql -uroot -p < lab1/sql/01-schema.sql
mysql -uroot -p < lab1/sql/02-seed.sql
export MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=department
export MYSQL_PWD=local-student-password
.build/lab1-run list
```

Обліковий запис `department` для окремого сервера потрібно створити з правами на `department_resources`; Docker створює його автоматично.

## Перевірки та вимірювання

- 42 автоматичні перевірки алгоритмів, формату архіву, пулу потоків, тексту та валідації.
- Інтеграційні перевірки MySQL: пошук, створення, редагування, зв’язки, статистика, помилкові дати, зовнішні ключі й SQL-ін’єкції.
- Побайтове порівняння відновлених файлів; архіви для 1 та 4 потоків ідентичні.
- [Журнали перевірок](verification), [умови запуску](verification/environment.json), [результати вимірювань](lab2/benchmark.csv).

| Потоки | Медіана, с | Прискорення | Ефективність |
| --- | --- | --- | --- |
| 1 | 0.670740 | 1.0000 | 1.0000 |
| 2 | 0.399344 | 1.6796 | 0.8398 |
| 4 | 0.228518 | 2.9352 | 0.7338 |

8 файлів по 1 МіБ, Ryzen 5 5600H, 12 логічних процесорів, GHC 9.6.7, `-O2 -threaded`. Медіана трьох запусків. Вимірюється стиснення попередньо завантажених даних; перевірка розпакування виконується поза таймером. Значення залежать від обладнання та навантаження.

## Склад для здачі

У кожній `labN`: код у `src` та `app`, інструкція, звіт `report.md`, `report.docx`, `report.pdf`. У першій — SQL, у другій — специфікація архіву і CSV, у третій — текст підручника та фактичний результат. [DEFENSE.md](DEFENSE.md) містить пояснення для захисту. Вихідні умови збережено в `assignments`.

Програми консольні, тому вебхостинг для виконання завдань не потрібний.

## Відтворення звітів

PDF та DOCX вже включено. На Windows їх можна повторно сформувати з `labN/report.md`:

```powershell
npm.cmd install --prefix .tools --no-audit --no-fund docx@9.5.1 pdfkit@0.17.2 @napi-rs/canvas@0.1.80 pdfjs-dist@5.4.296
node scripts/reports.mjs
node scripts/check-reports.mjs
```

Використовуються системні шрифти Times New Roman та Consolas. Перевірка PDF контролює український текст, наявність ПІБ і групи, порожні сторінки та праве поле; мініатюри зберігаються в `.tools/previews`.
