show con_name;
SELECT * FROM HR.COUNTRIES; -- Use Schema check table
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') FROM dual; -- Check Schema's name
SELECT TABLESPACE_NAME, STATUS, CONTENTS FROM USER_TABLESPACES; -- Check all Tablespaces
SELECT * FROM user_tables; -- check users' tables
select table_name, tablespace_name, owner from all_tables Where owner like '%HR%'; -- List all tables
SELECT file_name FROM dba_data_files; -- check all datafiles

-- SQL CREATE TESTING TABLE
-- Create the staff table
CREATE TABLE HR.staff (
    staff_id NUMBER,
    staff_name VARCHAR2(100),
    staff_department VARCHAR2(100),
    staff_position VARCHAR2(100),
    staff_salary NUMBER
);

-- Insert data into the staff table
INSERT INTO staff (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (1, 'John Doe', 'IT', 'Manager', 5000);

INSERT INTO staff (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (2, 'Jane Smith', 'HR', 'Supervisor', 4000);

INSERT INTO staff (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (3, 'Michael Johnson', 'Sales', 'Executive', 4500);

INSERT INTO staff (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (4, 'Emily Davis', 'Marketing', 'Coordinator', 3500);

INSERT INTO staff (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (5, 'Robert Wilson', 'Finance', 'Analyst', 3800);
-- END SQL
ALTER TABLE HR.staff
ADD staff_credit_card_no VARCHAR2(19);
--
UPDATE HR.staff
SET staff_credit_card_no = 
DECODE(staff_position, 'Manager', 12345678); -- Lenh update theo dieu kien
--
SELECT * FROM staff;
--
COMMIT

--

select table_name
     , column_name
     , encryption_alg
  from dba_encrypted_columns;