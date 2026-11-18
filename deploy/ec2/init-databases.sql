\set ON_ERROR_STOP on
\getenv account_password ACCOUNT_DB_PASSWORD
\getenv product_password PRODUCT_DB_PASSWORD

SELECT format('CREATE ROLE account_app LOGIN PASSWORD %L', :'account_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'account_app') \gexec
SELECT format('CREATE ROLE product_app LOGIN PASSWORD %L', :'product_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'product_app') \gexec

GRANT account_app, product_app TO CURRENT_USER WITH SET TRUE;

SELECT 'CREATE DATABASE store OWNER account_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'store') \gexec
SELECT 'CREATE DATABASE product OWNER product_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'product') \gexec

REVOKE CONNECT ON DATABASE store FROM PUBLIC;
REVOKE CONNECT ON DATABASE product FROM PUBLIC;
