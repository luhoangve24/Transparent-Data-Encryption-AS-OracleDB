
-- LÊ HOÀNG VŨ - 23A4040156
------------------------

-- HƯỚNG DẪN SỬ DỤNG TÍNH NĂNG TRANSPARENT DATA ENCRYPTION

------------------------
-- Tóm tắt:
-- 1, Cài đặt nơi lưu trữ kho khóa (Software Keystore Location)
-- 2, Cài đặt kho khóa với mật khẩu bảo vệ kho khóa, Auto-Login
-- 3, Mở kho khóa
-- 4, Cài đặt Master Key cho CDB và PDB
-- 5, Tạo bản Backup Full
-- 6, Mã hóa
------
-- # Yêu cầu: đăng nhập SQL*Plus với quyền SYSDBA
------

-- 1, Cài đặt nơi lưu trữ kho khóa

- Tạo folder wallet
-- cd C:\Oracle\app\oracle\admin\banking
-- mkdir wallet

-- - Kiểm tra các biến
-- show parameter wallet_root
-- show parameter tde_configuration

-- Đặt biến WALLET_ROOT với folder chỉ định như vừa tạo, cùng một vài tham số
ALTER SYSTEM SET WALLET_ROOT = 'C:\Oracle\app\oracle\admin\banking\wallet' SCOPE = SPFILE SID = '*';
-- # SCOPE:  cho phép bạn chỉ định khi nào thay đổi có hiệu lực. Phạm vi tùy thuộc vào việc bạn khởi động cơ sở dữ liệu bằng tệp tham số phía máy khách (pfile) hay tệp tham số máy chủ (spfile).
-- # SPfile: Cài đặt mới có hiệu lực khi cơ sở dữ liệu được tắt vào lần tiếp theo và khởi động lại.
-- # SID: liên quan đến Database dạng RAC

-- Restart lại database và check để biến wallet_root nhận (SPFile)
shutdown immediate
startup
show parameter wallet_root

-- Cài đặt biến TDE_CONFIGURATION để thiết lập kiểu kho lưu trữ khóa
ALTER SYSTEM SET TDE_CONFIGURATION="KEYSTORE_CONFIGURATION=FILE" SCOPE=BOTH SID = '*';
show parameter tde_configuration
-- # BOTH: Cài đặt mới có hiệu lực ngay lập tức và tiếp tục tồn tại sau khi cơ sở dữ liệu bị tắt và khởi động lại.

-- 2, Cài đặt kho khóa với mật khẩu bảo vệ kho khóa (Keystore), Auto-Login

-- # Lệnh SELECT * FROM V$ENCRYPTION_WALLET tự động mở auto-login software keystore
-- # Tham khảo câu trả lời tại: https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/configuring-transparent-data-encryption.html#GUID-5DAB02E7-CEE2-4C06-B2E0-6070F7BF8BDE
-- Kiểm tra lại nơi các object bảo mật của TDE sẽ được thiết lập (kỳ vọng là trong Wallet)
select wrl_parameter from v$encryption_wallet;

-- Với đặc quyền ADMINISTER KEY MANAGEMENT hoặc SYSKM, tạo kho lưu trữ khóa với mật khẩu được bảo vệ như sau
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE IDENTIFIED BY {software_keystore_password};
-- # Mình đặt software_keystore_password là 12345 không được -> chuyển thành P4ssW0rd thì ok, chắc do tiêu chuẩn bảo mật
-- # Thư mục /tde sẽ được tạo tự động trong /wallet nếu chưa có
-- # Sau khi chạy, tệp ewallet.p12 sẽ xuất hiện, chính là kho lưu trữ khóa, tiêu chuẩn PKCS#12

-- Với đặc quyền ADMINISTER KEY MANAGEMENT hoặc SYSKM, tạo phương thức auto-login cho kho khóa
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE 
FROM KEYSTORE 'keystore_location' 
IDENTIFIED BY 'software_keystore_password';

-- # 'keystore_location': C:\Oracle\app\oracle\admin\banking\wallet\tde
-- # 'software_keystore_password': P4ssW0rd
-- # -> xuất hiện file cwallet.sso, xác thực mở khóa tự động, nếu thêm LOCAL trước AUTO_LOGIN
-- # thì với mô hình RAC trong Oracle, chỉ node đầu tiên mới có thể truy cập vào Keystore để lấy khóa
-- # -- CẢNH BÁO --
-- # - Không xóa kho ewallet.p12 sau khi tạo cwallet.sso
-- #   ewallet.p12 PKCS#12 dùng để tạo lại TDE master key
-- # - TDE chỉ thực hiện auto-login keystore nếu keystore
-- #   được lưu trữ đúng địa điểm

-- 3, Mở kho khóa

-- # Chúng ta phải mở kho khóa sau khi tạo để có thể sử dụng nó cho việc lưu trữ khóa Master Key
-- # Với cơ chế auto-login, thì status của kho sẽ luôn là open-with-no-master-key khi chúng ta truy vấn v$encryption_wallet
-- # Nó sẽ vẫn tự động mở/đóng, trước khi người dùng truy vấn -> nên chúng ta thấy status là open
-- # Còn không, đối với mở khóa bằng mật khẩu thông thường (password-protected) thì với quyền ADMINISTER KEY MANAGEMENT hoặc SYSKM và mở theo tài liệu hướng dẫn tại
-- # https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/configuring-transparent-data-encryption.html#GUID-15E41F0A-5D80-4A7A-88F6-30EE86FA44E8
-- - Kiểm tra lại các trường của khóa
set pages 200
set lines 200
col WRL_PARAMETER for a40
select WRL_PARAMETER,WALLET_TYPE,KEYSTORE_MODE,status from v$encryption_wallet;
-- # -> OPEN_NO_MASTER_KEY: kho khóa đã mở, nhưng chưa tạo TDE Master Encryption Key

-- 4, Cài đặt Master Key cho CDB và PDB

-- # TDE Master Encryption Key được lưu trữ trong Keystore
-- # TDE MEK dùng để mã hóa, bảo vệ TDE Table Keys và Tablespace Encryption Keys
-- # Hiểu đơn giản, giống như từ Master Key trong hệ AES tạo ra các Keys tiếp theo tùy thuộc số vòng lặp

-- - Kiểm tra đang kết nối đến CDB hay PDB và đảm bảo phải đang ở chế độ READ/WRITE
show con_name;

-- Truy vấn chế độ
select OPEN_MODE from V$DATABASE;

-- -- Với quyền AKM (Administer Key Management) hoặc SYSKM, chạy
-- ADMINISTER KEY MANAGEMENT SET KEY 
-- [USING TAG 'tag'] # Đặt tên đầy đủ thông tin
-- [FORCE KEYSTORE] # Dùng cho password-based, auto-login vẫn cần vì cơ chế chỉ mở khi có truy vấn
-- IDENTIFIED BY [EXTERNAL STORE] | keystore_password # Nhập mật khẩu
-- [WITH BACKUP [USING 'backup_identifier']]; # Tạo một bản backup cho Keystore, sau Using ghi tag kiểu 'ewallet_time_stamp_emp_key_backup.p12'
--
 administer key management
    set key
    using tag 'master-key'
    force keystore
    identified by P4ssW0rd
    with backup using 'ewallet_11-11-2023_CDB_key_backup';
--

-- Kiểm tra lại Status
select * from v$ENCRYPTION_WALLET;

-- Kiểm tra xem các khóa đã thiết lập
SELECT KEY_ID,creation_time,activation_time,tag FROM V$ENCRYPTION_KEYS;

-- Kiểm tra tệp backup cho keystore được thiết lập bằng cmd
-- cd C:\Oracle\app\oracle\admin\banking\wallet\TDE
-- dir
-- # Sẽ có kết quả thêm tệp backup vừa tạo

-- # ---> Các bước trên mới xong thiết lập khóa cho CDB$ROOT, chúng ta còn PDB chưa thiết lập
-- # Bước tiếp theo thiết lập cho PDB

-- Kiểm tra trạng thái các PDB hoạt động
show pdbs;
# Trạng thái Mounted: chưa hoạt động
alter pluggable database {pdb name} open;
{pdb name}: bankingpdb # máy của mình

- Đổi session sang PDB để thiết lập
alter session set container={pdb name};
{pdb name}: bankingpdb # máy của mình

- Kiểm tra xem kho đã có TDE MEK chưa
select * from v$encryption_wallet;
# -> OPEN_NO_MASTER_KEY: chưa có TDE Master Encryption Key
SELECT KEY_ID,creation_time,activation_time,tag FROM V$ENCRYPTION_KEYS;
# -> no rows selected: kho chưa có TDE MEK nên tất nhiên khóa chưa có (ngược lại hợp lý hơn)

- Tạo khóa cho PDB, cụ thể của mình là BankingPDB, tương tự như tạo ở CDB 
administer key management
    set key
    using tag 'bankingpdb-master-key'
    force keystore
    identified by P4ssW0rd
    with backup using 'ewallet_11-11-2023_Banking-PDB_key_backup';

- Check lại, status OPEN thì ok
select * from v$ENCRYPTION_WALLET;

- Xem "mặt mũi" khóa cho PDB
SELECT KEY_ID,creation_time,activation_time,tag FROM V$ENCRYPTION_KEYS;

- Quay lại CDB để tổng kiểm MEK cho CDB và PDB
alter session set container=CDB$ROOT;
select * from v$ENCRYPTION_WALLET;
SELECT KEY_ID,creation_time,activation_time,tag FROM V$ENCRYPTION_KEYS;

- Kiểm tra log file bằng cmd nếu cần
cd /app/oracle/diag/rdbms/{SID}/{SID}/trace/alert_{SID}.log
# {SID} của mình lúc cài đặt là: banking

- Kiểm thử shutdown và start xem Auto-Login hoạt động như dự định
shut immediate
startup
select * from v$ENCRYPTION_WALLET;
# Status mà OPEN hết CDB và PDB thì ok

- Mở lại PDB để thực hiện các hành động tiếp theo
show pdbs;
alter pluggable database all open;

5, Tạo bản Backup Full

- Xem trạng thái FULLY_BAC, ở NO tức là chưa có Backup
select * from v$ENCRYPTION_WALLET;

- Đặt Full Back up MEK cho các DB này
administer key management backup keystore using 'Walletfullbackup' force keystore identified by {keystore_password};
# {keystore_password}: của mình là P4ssW0rd

- Check lại bằng cmd nếu cần thiết
cd C:\Oracle\app\oracle\admin\banking\wallet\TDE
dir

6, Mã hóa

- Đăng nhập vào PDB BankingPDB với roles HR
CONN hr/12345@localhost:1521/bankingpdb

- Kiểm tra các bảng thuộc về HR
select table_name from user_tables;
# Có bảng STAFF
# Thấy cột STAFF_CREDIT_CARD_NO khá quan trọng, giả sử mình là tin tặc, đi tìm file .dbf ở trong thư mục sau
# C:\Oracle\app\oracle\oradata\BANKING\bankingpdb, và vì mặc định bảng tạo ra hay lưu tại tablespaces USERS, với datafiles là USER01.dbf
# Copy USER01.dbf mang đi đào bới thông tin, dùng Search Tools tìm được Credit Card là '123456...' chẳng hạn, vì nó đang ở PlainText hết
# Chưa được mã hóa -> rất dễ lộ thông tin

- Mã hóa cột STAFF_CREDIT_CARD với roles hr sysdba
ALTER TABLE staff MODIFY (staff_credit_card_no ENCRYPT);
# Mặc định mã hóa theo AES192. Salt sẽ được thêm theo mặc định, nếu muốn đánh index
# thì thêm biến NO SALT, và cũng có thể bỏ đi tính vẹn toàn khi sử dụng biến NOMAC

- Chuyển roles system để check bảng với cột được mã hóa
CONN system/12345@localhost:1521/bankingpdb

select table_name
     , column_name
     , encryption_alg
  from dba_encrypted_columns

- Có thể thử khi insert credit card mới -> khi tìm bằng NotePad sẽ không tìm thấy. EZ! có thể so sánh trước khi áp dụng mã hóa và sau khi áp dụng mã hóa.
-> Cơ chế: bật mã hóa lên thì các trường dữ liệu insert sau mới được mã hóa, trước đó insert vào sẽ không được mã hóa.

- Ngoài ra, còn lệnh bỏ mã hóa ở cột đi để so sánh
ALTER TABLE {table_name} MODIFY ({col_name} DECRYPT);
-----
Tài liệu tham khảo
-- https://www.tranvanbinh.vn/2021/08/kiem-tra-bat-tat-cdb-pdb-voi-sqlplus.html
-- https://smarttechways.com/2021/10/05/configuring-transparent-data-encryption-tde-in-oracle-19c/#comments\
-- https://www.funoracleapps.com/2023/03/tde-transparent-data-encryption-in.html
-- https://dbsguru.com/configure-tde-transparent-data-encryption-in-oracle-database-19c-multitenant/
-- https://logic.edchen.org/how-oracle-enable-tde-on-rac-19c-db/#prepare-wallet-for-node-2
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/configuring-transparent-data-encryption.html#GUID-0AB76778-7D98-4C23-B848-C00BD05DFEFE