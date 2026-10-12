# Barz-backend terminal command lines execution
Remember that syntax commands through terminal such as:

```
fly postgres connect -a barzdb -d barz_db -c "SELECT id, firebase_uid, phone_number, email, google_id FROM users WHERE email LIKE '%carlos%' OR phone_number LIKE '%55%' ORDER BY id;"
```

doesn't work, you must add the following approach where you select the exact value you want:

```
psql -d barz_db -c "DELETE FROM menu_items;" && psql -d barz_db -c "DELETE FROM menus;" && psql -d barz_db -c "SELECT setval('menus_id_seq', 1, false);" && psql -d barz_db -c "SELECT setval('menu_items_id_seq', 1, false);"
```

The following command doesn't work either:

```
(venv) ➜  barz-backend git:(main) ✗ fly postgres connect -a barzdb -d barz_db -c "SELECT colum
n_name FROM information_schema.columns WHERE table_name='menus' ORDER BY column_name;"

Unmanaged Fly Postgres is not supported by Fly.io Support and users are responsible for operations, management, and disaster recovery. If you'd like a managed, supported solution, try 'fly mpg' (Managed Postgres).
Please visit https://fly.io/docs/mpg/overview/ for more information about Managed Postgres.

Connecting to fdaa:14:b85e:a7b:516:3200:d93f:2... complete
psql (17.7 (Ubuntu 17.7-3.pgdg24.04+1))
Type "help" for help.

barz_db=# 
```

Always try to run postgres related commands via psql interactive.
