-- Dang nhap voi user sys roles sysdba
show con_name;
alter session set container=bankingpdb; -- Chuyen qua PDB Banking neu van con o root
-- alter session set container=CDB$ROOT;
SELECT TABLESPACE_NAME, STATUS, CONTENTS FROM USER_TABLESPACES; -- Show cac tablespace thuoc sys (neu role HR thi chuyen account) o container hien tai
select table_name, tablespace_name, owner from all_tables Where owner like '%HR%'; -- List cac table thuoc schema HR/ALL
SELECT file_name FROM dba_data_files WHERE tablespace_name = 'USERS'; -- Show path data file chua tablespace chua object table tren (TEST_01/TEST_02)
-- select * from hr.staff; -- List cac cot thuoc bang Staff schema HR



-- Kiem tra cac cot duoc ma hoa
select table_name
     , column_name
     , encryption_alg
  from dba_encrypted_columns;


-- Tao tablespace
CREATE BIGFILE TABLESPACE TEST_01
DATAFILE 'C:\Oracle\app\oracle\oradata\BANKING\bankingpdb\test_01.dbf'
size 20M AUTOEXTEND ON;

DROP TABLESPACE TEST_01 INCLUDING CONTENTS AND DATAFILES; -- DROP TBS
ALTER USER hr quota unlimited on TEST_01;


-- Tao bang data staff ten staff_01 Tablespace TEST_01 file TEST_01.dbf
CREATE TABLE HR.staff_01 (
    staff_id NUMBER,
    staff_name VARCHAR2(100),
    staff_department VARCHAR2(100),
    staff_position VARCHAR2(100),
    staff_salary NUMBER
)
TABLESPACE TEST_01;

INSERT INTO hr.staff_01 (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (1, 'John Doe', 'IT', 'Manager', 5000);

INSERT INTO hr.staff_01 (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (2, 'Jane Smith', 'HR', 'Supervisor', 4000);

INSERT INTO hr.staff_01 (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (3, 'Michael Johnson', 'Sales', 'Executive', 4500);

INSERT INTO hr.staff_01 (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (4, 'Emily Davis', 'Marketing', 'Coordinator', 3500);

INSERT INTO hr.staff_01 (staff_id, staff_name, staff_department, staff_position, staff_salary)
VALUES (5, 'Robert Wilson', 'Finance', 'Analyst', 3800);
SELECT * FROM staff_01;
ALTER TABLE HR.staff_01
ADD staff_credit_card_no VARCHAR2(19);
--
UPDATE HR.staff_01
SET staff_credit_card_no = 
DECODE(staff_position, 'Manager', 12345678); -- Lenh update theo dieu kien
--
COMMIT;



-- Online Redefinition (cung TableSpace TEST_01 -> KET LUAN: Khong xoa het original text trong file TEST_01.dbf)
EXECUTE dbms_redefinition.can_redef_table ('HR','STAFF_01'); --  Kiem tra co the di chuyen ko
CREATE TABLE hr.staff_02 TABLESPACE TEST_01 as SELECT * FROM hr.staff_01;
DROP TABLE HR.STAFF_02;
ALTER TABLE hr.staff_02 MODIFY (STAFF_CREDIT_CARD_NO ENCRYPT);
EXECUTE dbms_redefinition.start_redef_table ('HR','STAFF_01','STAFF_02');
EXECUTE dbms_redefinition.finish_redef_table ('HR','STAFF_01','STAFF_02');
DROP TABLE HR.STAFF_01;

SELECT * FROM HR.staff_01;
--


-- Tao Tablespace chua rieng biet ten TEST_02
CREATE BIGFILE TABLESPACE TEST_02
DATAFILE 'C:\Oracle\app\oracle\oradata\BANKING\bankingpdb\test_02.dbf'
size 20M AUTOEXTEND ON;
ALTER USER hr quota unlimited on TEST_02;

-- Online Redefinition (data cu - staff_02 o tablespace TEST_01 migrate sang tablespace TEST_02 moi tao -> KET LUAN: xu ly duoc het original text)
EXECUTE dbms_redefinition.can_redef_table ('HR','STAFF_02');
CREATE TABLE hr.staff_03 TABLESPACE TEST_02 as (SELECT * FROM hr.staff_02 WHERE 1=2); -- Copy attributes
SELECT * FROM hr.staff_03; -- check
ALTER TABLE hr.staff_03 MODIFY (STAFF_CREDIT_CARD_NO ENCRYPT);
EXECUTE dbms_redefinition.start_redef_table ('HR','STAFF_02','STAFF_03'); -- Sync Data
EXECUTE dbms_redefinition.finish_redef_table ('HR','STAFF_02','STAFF_03'); -- Xoa cac thuoc tinh trung gian