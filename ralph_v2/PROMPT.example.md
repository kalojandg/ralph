# Example Prompt for Ralph Wiggum Algorithm

Това е примерен PROMPT файл. Копирай го като `PROMPT.md` и редактирай според нуждите си.

## Your Task Description

Описание на задачата която искаш Claude да изпълни...

### Context

Предай контекст:
- Какъв е проектът?
- Къде се намираме в процеса?
- Какво вече е направено?

### Requirements

Конкретни изисквания:
1. Първо изискване
2. Второ изискване
3. Трето изискване

### Expected Output

Какво очакваш като резултат:
- Файлове които трябва да се създадат/променят
- Функционалност която трябва да работи
- Тестове които трябва да минават

### Success Criteria

Как да разбереш че задачата е завършена?

**Важно**: За да Ralph знае че е завършено, добави в отговора си:

```
<promise>COMPLETE</promise>
```

Или дефинирай собствени критерии в `ralph-config.json`.

### Additional Instructions

Допълнителни инструкции за Claude:
- Coding style
- Frameworks to use
- Constraints
- etc.

---

## Example: Real Task

```
# Task: Create a Simple REST API

## Context
I need a REST API for a todo application using Node.js and Express.

## Requirements
1. Create Express server on port 3000
2. Implement CRUD endpoints for todos:
   - GET /todos - list all
   - POST /todos - create new
   - PUT /todos/:id - update
   - DELETE /todos/:id - delete
3. Use in-memory storage (array)
4. Add basic error handling

## Expected Output
- server.js file with Express server
- Working endpoints
- Basic validation

## Success Criteria
When all endpoints are implemented and tested, respond with:
<promise>COMPLETE</promise>
```

---

💡 **Tip**: Ако използваш `user-steps.md`, там можеш да добавиш динамични инструкции без да променяш този файл!
