# Лабораторна робота №1

**Левківський Євгеній Сергійович · ІПС-41**

Перше завдання: інформаційна система «Інформаційні ресурси кафедри» на Haskell та MySQL. 11 таблиць, пошук, додавання та коригування даних, статистика використання.

```powershell
node scripts/local.mjs lab1 list
node scripts/local.mjs lab1 search Haskell
node scripts/local.mjs lab1 catalog
node scripts/local.mjs lab1 details 1
node scripts/local.mjs lab1 stats
node scripts/local.mjs lab1 add "Новий ресурс" "Анотація" 1 1 2026-10-01 -
node scripts/local.mjs lab1 update 4 "Оновлений ресурс" "Нова анотація" 2 2 2026-10-01 2027-06-30
node scripts/local.mjs lab1 link-author 4 3
node scripts/local.mjs lab1 link-purpose 4 2
node scripts/local.mjs lab1 url-add 4 https://example.org/resource
node scripts/local.mjs lab1 grant 4 1
node scripts/local.mjs lab1 visit 4 1 120
node scripts/local.mjs lab1 edit authors 3 name "Левківський Євгеній Сергійович"
```

Команди запускаються з кореня репозиторію. ID нового ресурсу програма друкує після `add`; у прикладі `4` слід замінити фактичним ID. Звіт: [PDF](report.pdf), [DOCX](report.docx), [Markdown](report.md).

## Класи та екземпляри

`SqlValue` перетворює `Text`, `Int`, `Day`, `Maybe a` на SQL-значення; текст передається як UTF-8 hex literal. `Validatable ResourceDraft` перевіряє назву, довідники й дати. `ResourceStore MySQL` реалізує CRUD та пошук через єдиний інтерфейс.

Haskell відповідає за моделі, правила, формування SQL і інтерфейс. Офіційний клієнт `mysql` є транспортом до реального сервера MySQL; обмін відбувається через stdin/stdout. Пароль береться клієнтом із середовища `MYSQL_PWD`.

## Схема

```mermaid
erDiagram
  resource_types ||--o{ resources : type
  usage_terms ||--o{ resources : terms
  resources ||--o{ resource_authors : authors
  authors ||--o{ resource_authors : resources
  resources ||--o{ resource_purposes : purposes
  purposes ||--o{ resource_purposes : resources
  resources ||--o{ resource_urls : addresses
  resources ||--o{ access_grants : access
  users ||--o{ access_grants : users
  access_grants ||--o{ usage_events : visits
```

`usage_events` посилається на складений ключ наданого доступу; відвідування без доступу відхиляє БД. `resource_statistics` — представлення, а не додаткова таблиця. `CHECK` забороняє термін завершення раніше відкриття. Демонстраційні дані відокремлені від схеми.
