-- ═══════════════════════════════════════════════════════════════════════════
-- HOSPITAL MANAGEMENT SYSTEM DATABASE — IMPROVED & PRODUCTION-READY
-- ═══════════════════════════════════════════════════════════════════════════
-- Project    : HospitalManagementDB
-- Version    : 2.0 (Improved from Hospital_final_2.sql)
-- Date       : March 2026
-- Engine     : Microsoft SQL Server 2019+
-- Author     : Senior Database Engineering Team
--
-- IMPROVEMENT SUMMARY (vs Hospital_final_2.sql):
-- ─────────────────────────────────────────────────────────────────────────
--  [IMP-01] national_id changed from UNIQUE (nullable) to UNIQUE NOT NULL
--  [IMP-02] gender made NOT NULL across all tables
--  [IMP-03] blood_group column widened to VARCHAR(5) to safely hold 'AB+'
--  [IMP-04] Staff.first_name/last_name standardised from VARCHAR to NVARCHAR
--  [IMP-05] Staff.email widened from VARCHAR(50) to NVARCHAR(100) for parity
--  [IMP-06] Doctors.manager_id self-referencing FK added (was declared, never defined)
--  [IMP-07] Doctors.email made NOT NULL (was nullable)
--  [IMP-08] Room_Types.room_type_name given UNIQUE constraint
--  [IMP-09] Rooms.status given DEFAULT 'Available'
--  [IMP-10] Blood_Bank.blood_type made NOT NULL; last_updated given DEFAULT
--  [IMP-11] Ambulance.ambulance_number made NOT NULL
--  [IMP-12] Billing.paid_amount column added for cumulative payment tracking
--  [IMP-13] Workers.staff_id made NOT NULL
--  [IMP-14] Pharmacy FK columns made NOT NULL where business logic requires
--  [IMP-15] Missing indexes added (medicine_type, medicine_expiry, billing_status)
--  [IMP-16] Blood_Transfusion_Log retained from original (was removed in FINAL.sql)
--  [IMP-17] Comprehensive data seeding for ALL 22 tables
--  [IMP-18] 6 Stored Procedures (was 0 in original, 3 in FINAL)
--  [IMP-19] 3 DML Triggers for business rule enforcement
--  [IMP-20] 5 RBAC Roles with GRANT/DENY security matrix
--  [IMP-21] 10 Analytical Views + 2 Audit Views
--  [IMP-22] Receptionist role added to security model
--
-- CONTENTS:
--   SECTION 1 — Database & Schema Creation (22 Tables)
--   SECTION 2 — Data Seeding (Comprehensive Test Data)
--   SECTION 3 — Performance Indexes
--   SECTION 4 — 10 Analytical Views
--   SECTION 5 — Role-Based Access Control (6 Roles)
--   SECTION 6 — Stored Procedures (6 Procedures)
--   SECTION 7 — Triggers (3 Triggers)
--   SECTION 8 — Audit & Monitoring Views
--   SECTION 9 — Status Report & Test Scripts
-- ═══════════════════════════════════════════════════════════════════════════

USE master;
GO

-- Safe drop & recreate
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'HospitalManagementDB')
BEGIN
    ALTER DATABASE HospitalManagementDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HospitalManagementDB;
    PRINT '>> Previous database dropped';
END
GO

CREATE DATABASE HospitalManagementDB;
GO
USE HospitalManagementDB;
GO

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 1: DATABASE SCHEMA CREATION (22 Tables)';
PRINT '═══════════════════════════════════════════════════════';
GO

-- ─────────────────────────────────────────────────────────────
-- T1: PATIENTS — Core patient demographics & medical profile
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Patients (
    patient_id      INT PRIMARY KEY IDENTITY(1,1),
    first_name      NVARCHAR(50)  NOT NULL,
    last_name       NVARCHAR(50)  NOT NULL,
    national_id     NVARCHAR(20)  UNIQUE NOT NULL,          -- [IMP-01]
    date_of_birth   DATE          NOT NULL,
    gender          CHAR(1)       NOT NULL                   -- [IMP-02]
                    CHECK (gender IN ('M', 'F')),
    blood_group     VARCHAR(5)                               -- [IMP-03]
                    CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    contact_number  NVARCHAR(15),
    email           NVARCHAR(100),
    [address]       NVARCHAR(255),
    city            NVARCHAR(50),
    medical_history NVARCHAR(MAX),
    is_active       BIT           DEFAULT 1,
    created_at      DATETIME      DEFAULT GETDATE(),
    updated_at      DATETIME      DEFAULT GETDATE(),
    INDEX idx_patient_name       (last_name, first_name),
    INDEX idx_patient_national   (national_id),
    INDEX idx_patient_city       (city)
);

-- ─────────────────────────────────────────────────────────────
-- T2: DEPARTMENTS — Hospital organisational units
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Departments (
    department_id   INT PRIMARY KEY IDENTITY(1,1),
    department_name NVARCHAR(100) NOT NULL UNIQUE,
    is_active       BIT           DEFAULT 1,
    manager_id      INT           NULL,                      -- FK added after Doctors
    created_at      DATETIME      DEFAULT GETDATE(),
    INDEX idx_dept_name (department_name)
);

-- ─────────────────────────────────────────────────────────────
-- T3: DOCTORS — Medical practitioners
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Doctors (
    doctor_id           INT PRIMARY KEY IDENTITY(1,1),
    department_id       INT           NOT NULL,
    manager_id          INT           NULL,
    license_number      NVARCHAR(50)  UNIQUE NOT NULL,
    first_name          NVARCHAR(50)  NOT NULL,
    last_name           NVARCHAR(50)  NOT NULL,
    specialty           NVARCHAR(100) NOT NULL,
    job_title           NVARCHAR(50),
    years_of_experience INT,
    contact_number      NVARCHAR(15),
    email               NVARCHAR(100) UNIQUE NOT NULL,       -- [IMP-07]
    is_active           BIT           DEFAULT 1,
    created_at          DATETIME      DEFAULT GETDATE(),
    FOREIGN KEY (department_id) REFERENCES Departments(department_id),
    INDEX idx_doctor_name      (last_name, first_name),
    INDEX idx_doctor_specialty (specialty)
);

-- [IMP-06] Self-referencing FK for doctor hierarchy
ALTER TABLE Doctors
ADD CONSTRAINT FK_Doctor_Manager
FOREIGN KEY (manager_id) REFERENCES Doctors(doctor_id);

-- Circular FK resolved via ALTER
ALTER TABLE Departments
ADD CONSTRAINT FK_Dept_Manager
FOREIGN KEY (manager_id) REFERENCES Doctors(doctor_id);

-- ─────────────────────────────────────────────────────────────
-- T4: DOCTOR_DEPARTMENT — Many-to-Many bridge
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Doctor_Department (
    doctor_id     INT NOT NULL,
    department_id INT NOT NULL,
    PRIMARY KEY (doctor_id, department_id),
    FOREIGN KEY (doctor_id)     REFERENCES Doctors(doctor_id)         ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES Departments(department_id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────
-- T5: APPOINTMENTS — Patient scheduling
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Appointments (
    appointment_id   INT PRIMARY KEY IDENTITY(1,1),
    patient_id       INT           NOT NULL,
    doctor_id        INT           NULL,
    department_id    INT           NOT NULL,
    appointment_date DATE          NOT NULL,
    appointment_time TIME          NOT NULL,
    purpose          NVARCHAR(255),
    [status]         NVARCHAR(20)  DEFAULT 'Scheduled'
                     CHECK ([status] IN ('Scheduled','Confirmed','Completed','Cancelled','No Show')),
    created_at       DATETIME      DEFAULT GETDATE(),
    updated_at       DATETIME      DEFAULT GETDATE(),
    FOREIGN KEY (patient_id)    REFERENCES Patients(patient_id)       ON DELETE CASCADE,
    FOREIGN KEY (doctor_id)     REFERENCES Doctors(doctor_id)         ON DELETE SET NULL,
    FOREIGN KEY (department_id) REFERENCES Departments(department_id),
    CONSTRAINT UQ_Doctor_Time   UNIQUE (doctor_id, appointment_date, appointment_time),
    INDEX idx_appt_patient (patient_id),
    INDEX idx_appt_date    (appointment_date, appointment_time),
    INDEX idx_appt_status  ([status])
);

-- ─────────────────────────────────────────────────────────────
-- T6: MEDICAL_RECORDS — Clinical consultation documentation
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Medical_Records (
    record_id           INT PRIMARY KEY IDENTITY(1,1),
    patient_id          INT           NOT NULL,
    doctor_id           INT           NULL,
    appointment_id      INT           NULL,
    record_date         DATETIME      DEFAULT GETDATE(),
    diagnosis           NVARCHAR(MAX),
    treatment           NVARCHAR(MAX),
    prescription        NVARCHAR(MAX),
    lab_results_summary NVARCHAR(MAX),
    created_at          DATETIME      DEFAULT GETDATE(),
    updated_at          DATETIME      DEFAULT GETDATE(),
    FOREIGN KEY (patient_id)    REFERENCES Patients(patient_id)       ON DELETE CASCADE,
    FOREIGN KEY (doctor_id)     REFERENCES Doctors(doctor_id)         ON DELETE SET NULL,
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id),
    INDEX idx_medrec_patient (patient_id),
    INDEX idx_medrec_date    (record_date)
);

-- ─────────────────────────────────────────────────────────────
-- T7: BILLING — Invoice & payment tracking
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Billing (
    bill_id            INT PRIMARY KEY IDENTITY(1,1),
    patient_id         INT            NOT NULL,
    appointment_id     INT            NULL,
    invoice_number     AS ('INV-' + CAST(bill_id AS VARCHAR(10))),  -- Computed
    total_amount       DECIMAL(10,2)  NOT NULL,
    paid_amount        DECIMAL(10,2)  DEFAULT 0,                    -- [IMP-12]
    payment_status     NVARCHAR(20)   DEFAULT 'Pending'
                       CHECK (payment_status IN ('Pending','Paid','Partially Paid','Refunded')),
    payment_date       DATETIME       NULL,
    insurance_provider NVARCHAR(100),
    created_at         DATETIME       DEFAULT GETDATE(),
    FOREIGN KEY (patient_id)    REFERENCES Patients(patient_id)      ON DELETE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id),
    INDEX idx_billing_date   (created_at),
    INDEX idx_billing_status (payment_status)
);

-- ─────────────────────────────────────────────────────────────
-- T8: STAFF — All non-doctor hospital employees
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Staff (
    staff_id       INT PRIMARY KEY IDENTITY(1,1),
    first_name     NVARCHAR(50)  NOT NULL,                   -- [IMP-04]
    last_name      NVARCHAR(50)  NOT NULL,                   -- [IMP-04]
    gender         CHAR(1)       NOT NULL                    -- [IMP-02]
                   CHECK (gender IN ('M', 'F')),
    date_of_birth  DATE,
    [role]         NVARCHAR(20)  NOT NULL
                   CHECK ([role] IN ('Nurse','Worker','Admin','Pharmacist','Technician','Lab Assistant','Driver','Receptionist')),
    [shift]        NVARCHAR(20)
                   CHECK ([shift] IN ('Morning','Evening','Night','Rotating')),
    department_id  INT           NULL,
    contact_number NVARCHAR(15),
    email          NVARCHAR(100) UNIQUE,                     -- [IMP-05]
    [address]      NVARCHAR(MAX),
    hire_date      DATE,
    is_active      BIT           DEFAULT 1,
    FOREIGN KEY (department_id) REFERENCES Departments(department_id) ON DELETE SET NULL,
    INDEX idx_staff_role ([role]),
    INDEX idx_staff_dept (department_id)
);

-- ─────────────────────────────────────────────────────────────
-- T9: NURSES — ISA specialisation of Staff
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Nurses (
    staff_id               INT PRIMARY KEY,
    nursing_license_number NVARCHAR(50) UNIQUE,
    specialization         NVARCHAR(50),
    shift_hours            NVARCHAR(MAX),
    FOREIGN KEY (staff_id) REFERENCES Staff(staff_id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────
-- T10: WORKERS — ISA specialisation of Staff
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Workers (
    worker_id     INT PRIMARY KEY IDENTITY(1,1),
    staff_id      INT           NOT NULL,                    -- [IMP-13]
    job_title     NVARCHAR(50),
    work_schedule NVARCHAR(MAX),
    FOREIGN KEY (staff_id) REFERENCES Staff(staff_id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────
-- T11: MEDICINE — Pharmaceutical inventory
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Medicine (
    medicine_id    INT PRIMARY KEY IDENTITY(1,1),
    [name]         NVARCHAR(100) NOT NULL,
    brand          NVARCHAR(50),
    [type]         NVARCHAR(20)
                   CHECK ([type] IN ('Tablet','Capsule','Liquid','Injection','Ointment','Inhaler','Drops')),
    dosage         NVARCHAR(50),
    stock_quantity INT           CHECK (stock_quantity >= 0),
    [expiry_date]  DATE,
    is_active      BIT           DEFAULT 1,
    created_at     DATETIME      DEFAULT GETDATE(),
    INDEX idx_medicine_name   ([name]),
    INDEX idx_medicine_type   ([type]),
    INDEX idx_medicine_expiry ([expiry_date])
);

-- ─────────────────────────────────────────────────────────────
-- T12: PHARMACY — Medication dispensing log
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Pharmacy (
    pharmacy_id       INT PRIMARY KEY IDENTITY(1,1),
    medicine_id       INT           NOT NULL,                -- [IMP-14]
    patient_id        INT           NOT NULL,                -- [IMP-14]
    record_id         INT           NULL,
    doctor_id         INT           NULL,
    quantity          INT           NOT NULL CHECK (quantity > 0),
    prescription_date DATETIME      DEFAULT GETDATE(),
    FOREIGN KEY (medicine_id) REFERENCES Medicine(medicine_id)       ON DELETE CASCADE,
    FOREIGN KEY (patient_id)  REFERENCES Patients(patient_id)        ON DELETE CASCADE,
    FOREIGN KEY (doctor_id)   REFERENCES Doctors(doctor_id),
    FOREIGN KEY (record_id)   REFERENCES Medical_Records(record_id)
);

-- ─────────────────────────────────────────────────────────────
-- T13: BLOOD_BANK — Blood inventory management
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Blood_Bank (
    blood_id       INT PRIMARY KEY IDENTITY(1,1),
    blood_type     NVARCHAR(3) NOT NULL                      -- [IMP-10]
                   CHECK (blood_type IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    stock_quantity INT         CHECK (stock_quantity >= 0),
    last_updated   DATE        DEFAULT CAST(GETDATE() AS DATE), -- [IMP-10]
    INDEX idx_blood_type (blood_type)
);

-- ─────────────────────────────────────────────────────────────
-- T14: ROOM_TYPES — Hospital room categories
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Room_Types (
    room_type_id   INT PRIMARY KEY IDENTITY(1,1),
    room_type_name NVARCHAR(50) NOT NULL UNIQUE,             -- [IMP-08]
    [description]  NVARCHAR(255)
);

-- ─────────────────────────────────────────────────────────────
-- T15: ROOMS — Physical hospital rooms
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Rooms (
    room_id       INT PRIMARY KEY IDENTITY(1,1),
    room_number   VARCHAR(10) UNIQUE NOT NULL,
    room_type_id  INT         NULL,
    floor_number  INT,
    capacity      INT,
    [status]      NVARCHAR(20) DEFAULT 'Available'           -- [IMP-09]
                  CHECK ([status] IN ('Available','Occupied','Under Maintenance')),
    last_serviced DATE,
    FOREIGN KEY (room_type_id) REFERENCES Room_Types(room_type_id) ON DELETE SET NULL
);

-- ─────────────────────────────────────────────────────────────
-- T16: ROOM_ASSIGNMENTS — Room occupancy tracking
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Room_Assignments (
    assignment_id   INT PRIMARY KEY IDENTITY(1,1),
    room_id         INT           NOT NULL,
    staff_id        INT           NULL,
    patient_id      INT           NULL,
    assignment_type NVARCHAR(20)  NOT NULL
                    CHECK (assignment_type IN ('Patient Admission','Staff Shift','Maintenance')),
    assignment_date DATETIME      DEFAULT GETDATE(),
    end_date        DATETIME      NULL,
    FOREIGN KEY (room_id)    REFERENCES Rooms(room_id)       ON DELETE CASCADE,
    FOREIGN KEY (staff_id)   REFERENCES Staff(staff_id)      ON DELETE SET NULL,
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id) ON DELETE SET NULL,
    INDEX idx_roomassign_patient (patient_id),
    INDEX idx_roomassign_room    (room_id)
);

-- ─────────────────────────────────────────────────────────────
-- T17: CLEANING_SERVICE — Room cleaning log
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Cleaning_Service (
    service_id   INT PRIMARY KEY IDENTITY(1,1),
    room_id      INT           NOT NULL,
    staff_id     INT           NOT NULL,
    service_date DATE          DEFAULT CAST(GETDATE() AS DATE),
    service_time TIME          DEFAULT CAST(GETDATE() AS TIME),
    notes        NVARCHAR(255),
    FOREIGN KEY (room_id)  REFERENCES Rooms(room_id),
    FOREIGN KEY (staff_id) REFERENCES Staff(staff_id)
);

-- ─────────────────────────────────────────────────────────────
-- T18: PRESCRIPTION — Detailed prescription records
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Prescription (
    prescription_id   INT PRIMARY KEY IDENTITY(1,1),
    patient_id        INT           NOT NULL,
    doctor_id         INT           NOT NULL,
    record_id         INT           NULL,
    prescription_date DATE          DEFAULT CAST(GETDATE() AS DATE),
    medicine_id       INT           NOT NULL,
    dosage            NVARCHAR(100),
    frequency         NVARCHAR(50),
    duration          NVARCHAR(50),
    notes             NVARCHAR(255),
    FOREIGN KEY (patient_id)  REFERENCES Patients(patient_id),
    FOREIGN KEY (doctor_id)   REFERENCES Doctors(doctor_id),
    FOREIGN KEY (record_id)   REFERENCES Medical_Records(record_id),
    FOREIGN KEY (medicine_id) REFERENCES Medicine(medicine_id),
    INDEX idx_rx_patient (patient_id),
    INDEX idx_rx_doctor  (doctor_id),
    INDEX idx_rx_date    (prescription_date)
);

-- ─────────────────────────────────────────────────────────────
-- T19: AMBULANCE — Fleet management
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Ambulance (
    ambulance_id      INT PRIMARY KEY IDENTITY(1,1),
    ambulance_number  VARCHAR(10) UNIQUE NOT NULL,           -- [IMP-11]
    [availability]    NVARCHAR(15) DEFAULT 'Available'
                      CHECK ([availability] IN ('Available','On Duty','Maintenance')),
    driver_id         INT          NULL,
    last_service_date DATE,
    FOREIGN KEY (driver_id) REFERENCES Staff(staff_id) ON DELETE NO ACTION
);

-- ─────────────────────────────────────────────────────────────
-- T20: AMBULANCE_LOG — Ambulance trip tracking
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Ambulance_Log (
    log_id           INT PRIMARY KEY IDENTITY(1,1),
    ambulance_id     INT           NOT NULL,
    patient_id       INT           NOT NULL,
    pickup_location  NVARCHAR(100),
    dropoff_location NVARCHAR(100),
    pickup_time      DATETIME,
    dropoff_time     DATETIME,
    [status]         NVARCHAR(15)  DEFAULT 'In Progress'
                     CHECK ([status] IN ('Completed','In Progress','Canceled')),
    FOREIGN KEY (ambulance_id) REFERENCES Ambulance(ambulance_id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id)   REFERENCES Patients(patient_id)    ON DELETE CASCADE,
    INDEX idx_amblog_status ([status])
);

-- ─────────────────────────────────────────────────────────────
-- T21: BLOOD_TRANSFUSION_LOG — Blood usage tracking [IMP-16]
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Blood_Transfusion_Log (
    transfusion_id   INT PRIMARY KEY IDENTITY(1,1),
    blood_id         INT           NOT NULL,
    patient_id       INT           NOT NULL,
    doctor_id        INT           NOT NULL,
    record_id        INT           NULL,
    quantity         INT           NOT NULL CHECK (quantity > 0),
    transfusion_date DATETIME      DEFAULT GETDATE(),
    FOREIGN KEY (blood_id)   REFERENCES Blood_Bank(blood_id),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (doctor_id)  REFERENCES Doctors(doctor_id),
    FOREIGN KEY (record_id)  REFERENCES Medical_Records(record_id)
);

-- ─────────────────────────────────────────────────────────────
-- T22: MEDICAL_RECORDS_MEDICINE — Many-to-Many bridge
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Medical_Records_Medicine (
    record_id   INT NOT NULL,
    medicine_id INT NOT NULL,
    dosage      NVARCHAR(50),
    PRIMARY KEY (record_id, medicine_id),
    FOREIGN KEY (record_id)   REFERENCES Medical_Records(record_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id) REFERENCES Medicine(medicine_id)       ON DELETE CASCADE
);

PRINT '>> All 22 tables created successfully';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: DATA SEEDING — Comprehensive Test Data
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 2: DATA SEEDING';
PRINT '═══════════════════════════════════════════════════════';
GO

BEGIN TRANSACTION;

-- ── Departments (8) ──────────────────────────────────────────
SET IDENTITY_INSERT Departments ON;
INSERT INTO Departments (department_id, department_name, is_active) VALUES
    (1, 'Cardiology',        1),
    (2, 'Pediatrics',        1),
    (3, 'Orthopedics',       1),
    (4, 'Neurology',         1),
    (5, 'Dermatology',       1),
    (6, 'General Surgery',   1),
    (7, 'Internal Medicine', 1),
    (8, 'Emergency',         1);
SET IDENTITY_INSERT Departments OFF;

-- ── Room Types (5) ───────────────────────────────────────────
SET IDENTITY_INSERT Room_Types ON;
INSERT INTO Room_Types (room_type_id, room_type_name, [description]) VALUES
    (1, 'ICU',            'Intensive Care Unit'),
    (2, 'General Ward',   'Standard patient rooms'),
    (3, 'Operating Room', 'Surgical procedures'),
    (4, 'Laboratory',     'Medical testing'),
    (5, 'Private Suite',  'Premium single rooms');
SET IDENTITY_INSERT Room_Types OFF;

-- ── Blood Bank (8) ───────────────────────────────────────────
INSERT INTO Blood_Bank (blood_type, stock_quantity) VALUES
    ('A+',  50), ('A-',  25), ('B+',  40), ('B-',  15),
    ('AB+', 20), ('AB-', 10), ('O+',  60), ('O-',  35);

-- ── Doctors (10) ─────────────────────────────────────────────
SET IDENTITY_INSERT Doctors ON;
INSERT INTO Doctors (doctor_id, department_id, license_number, first_name, last_name, specialty, job_title, years_of_experience, email) VALUES
    (1,  1, 'LIC-001', 'Ahmed',   'Hassan',   'Cardiology',        'Consultant', 15, 'ahmed.hassan@hospital.eg'),
    (2,  1, 'LIC-002', 'Mohamed', 'Ali',       'Cardiology',        'Specialist',  8, 'mohamed.ali@hospital.eg'),
    (3,  2, 'LIC-003', 'Sara',    'Mahmoud',   'Pediatrics',        'Professor',  20, 'sara.mahmoud@hospital.eg'),
    (4,  2, 'LIC-004', 'Omar',    'Khaled',    'Pediatrics',        'Specialist',  6, 'omar.khaled@hospital.eg'),
    (5,  3, 'LIC-005', 'Tarek',   'Mostafa',   'Orthopedics',       'Consultant', 18, 'tarek.mostafa@hospital.eg'),
    (6,  4, 'LIC-006', 'Layla',   'Saeed',     'Neurology',         'Professor',  22, 'layla.saeed@hospital.eg'),
    (7,  6, 'LIC-007', 'Waleed',  'Hamdy',     'Surgery',           'Professor',  25, 'waleed.hamdy@hospital.eg'),
    (8,  7, 'LIC-008', 'Magdy',   'Rizk',      'Internal Medicine', 'Professor',  28, 'magdy.rizk@hospital.eg'),
    (9,  8, 'LIC-009', 'Adel',    'Shawky',    'Emergency',         'Consultant', 17, 'adel.shawky@hospital.eg'),
    (10, 8, 'LIC-010', 'Mariam',  'Lotfy',     'Emergency',         'Specialist',  6, 'mariam.lotfy@hospital.eg');
SET IDENTITY_INSERT Doctors OFF;

-- Set doctor managers (department heads supervise specialists)
UPDATE Doctors SET manager_id = 1 WHERE doctor_id = 2;   -- Mohamed reports to Ahmed (Cardiology)
UPDATE Doctors SET manager_id = 3 WHERE doctor_id = 4;   -- Omar reports to Sara (Pediatrics)
UPDATE Doctors SET manager_id = 9 WHERE doctor_id = 10;  -- Mariam reports to Adel (Emergency)

-- Set department managers
UPDATE Departments SET manager_id = 1  WHERE department_id = 1;
UPDATE Departments SET manager_id = 3  WHERE department_id = 2;
UPDATE Departments SET manager_id = 5  WHERE department_id = 3;
UPDATE Departments SET manager_id = 6  WHERE department_id = 4;
UPDATE Departments SET manager_id = 7  WHERE department_id = 6;
UPDATE Departments SET manager_id = 8  WHERE department_id = 7;
UPDATE Departments SET manager_id = 9  WHERE department_id = 8;

-- ── Doctor_Department bridge (10) ────────────────────────────
INSERT INTO Doctor_Department (doctor_id, department_id) VALUES
    (1,1),(2,1),(3,2),(4,2),(5,3),(6,4),(7,6),(8,7),(9,8),(10,8);

-- ── Patients (20) ────────────────────────────────────────────
SET IDENTITY_INSERT Patients ON;
INSERT INTO Patients (patient_id, first_name, last_name, national_id, date_of_birth, gender, blood_group, city, contact_number, medical_history, is_active) VALUES
    (1,  'Mohamed', 'Ahmed',       '29001011234501', '1990-01-01', 'M', 'A+',  'Cairo',       '01012345001', 'Hypertension',       1),
    (2,  'Fatma',   'Hassan',      '29205151234502', '1992-05-15', 'F', 'B+',  'Giza',        '01012345002', 'Penicillin allergy',  1),
    (3,  'Ahmed',   'Mohamed',     '28512201234503', '1985-12-20', 'M', 'O+',  'Cairo',       '01012345003', 'None',                1),
    (4,  'Sara',    'Ibrahim',     '29803101234504', '1998-03-10', 'F', 'AB+', 'Cairo',       '01012345004', 'Type 2 Diabetes',     1),
    (5,  'Omar',    'Ali',         '27506251234505', '1975-06-25', 'M', 'A-',  'Cairo',       '01012345005', 'Cardiac history',     1),
    (6,  'Nora',    'Mahmoud',     '30001151234506', '2000-01-15', 'F', 'B-',  'Alexandria',  '01012345006', 'None',                1),
    (7,  'Karim',   'Ahmed',       '29509081234507', '1995-09-08', 'M', 'O-',  'Mansoura',    '01012345007', 'Asthma',              1),
    (8,  'Layla',   'Said',        '28811301234508', '1988-11-30', 'F', 'AB-', 'Tanta',       '01012345008', 'Allergy',             1),
    (9,  'Youssef', 'Kamal',       '29207181234509', '1992-07-18', 'M', 'A+',  'Zagazig',     '01012345009', 'None',                1),
    (10, 'Mariam',  'Fouad',       '29604221234510', '1996-04-22', 'F', 'B+',  'Port Said',   '01012345010', 'Hypothyroidism',      1),
    (11, 'Ali',     'Shawky',      '28002141234511', '1980-02-14', 'M', 'O+',  'Aswan',       '01012345011', 'Arthritis',           1),
    (12, 'Hoda',    'Abdallah',    '29108081234512', '1991-08-08', 'F', 'A+',  'Cairo',       '01012345012', 'None',                1),
    (13, 'Hassan',  'Mohamed',     '28305051234513', '1983-05-05', 'M', 'B-',  'Cairo',       '01012345013', 'Back pain',           1),
    (14, 'Reem',    'Hussein',     '29712121234514', '1997-12-12', 'F', 'O+',  'Giza',        '01012345014', 'None',                1),
    (15, 'Ibrahim', 'Osman',       '27009091234515', '1970-09-09', 'M', 'AB+', 'Cairo',       '01012345015', 'CAD',                 1),
    (16, 'Mona',    'Eldin',       '29403031234516', '1994-03-03', 'F', 'A-',  'Cairo',       '01012345016', 'Migraine',            1),
    (17, 'Tarek',   'Abdelrahman', '28610101234517', '1986-10-10', 'M', 'B+',  'Cairo',       '01012345017', 'None',                1),
    (18, 'Dina',    'Amin',        '29906061234518', '1999-06-06', 'F', 'O-',  'Cairo',       '01012345018', 'None',                1),
    (19, 'Samer',   'Fahmy',       '28201011234519', '1982-01-01', 'M', 'A+',  'Cairo',       '01012345019', 'Gout',                1),
    (20, 'Rania',   'Nour',        '29307071234520', '1993-07-07', 'F', 'AB-', 'Heliopolis',  '01012345020', 'Anemia',              1);
SET IDENTITY_INSERT Patients OFF;

-- ── Staff (8) ────────────────────────────────────────────────
SET IDENTITY_INSERT Staff ON;
INSERT INTO Staff (staff_id, first_name, last_name, gender, date_of_birth, [role], [shift], department_id, email, hire_date, is_active) VALUES
    (1, 'Amira',   'Hassan',  'F', '1990-03-15', 'Nurse',        'Morning',  1,    'amira@hospital.eg',   '2018-01-15', 1),
    (2, 'Fatima',  'Ali',     'F', '1988-07-20', 'Nurse',        'Evening',  2,    'fatima@hospital.eg',  '2017-06-01', 1),
    (3, 'Mahmoud', 'Fathy',   'M', '1980-06-12', 'Worker',       'Morning',  NULL, 'mahmoud@hospital.eg', '2016-04-01', 1),
    (4, 'Maha',    'Nabil',   'F', '1987-08-22', 'Admin',        'Morning',  NULL, 'maha@hospital.eg',    '2015-01-01', 1),
    (5, 'Samir',   'Youssef', 'M', '1985-11-03', 'Driver',       'Rotating', 8,    'samir@hospital.eg',   '2019-03-10', 1),
    (6, 'Hanan',   'Farouk',  'F', '1992-04-18', 'Nurse',        'Night',    8,    'hanan@hospital.eg',   '2020-01-15', 1),
    (7, 'Noha',    'Salem',   'F', '1993-09-25', 'Receptionist', 'Morning',  NULL, 'noha@hospital.eg',    '2021-02-01', 1),
    (8, 'Khaled',  'Barakat', 'M', '1991-01-10', 'Pharmacist',   'Morning',  NULL, 'khaled@hospital.eg',  '2019-07-01', 1);
SET IDENTITY_INSERT Staff OFF;

-- ── Nurses ISA (3) ───────────────────────────────────────────
INSERT INTO Nurses (staff_id, nursing_license_number, specialization, shift_hours) VALUES
    (1, 'NUR-001', 'Cardiac Care',   '07:00 - 15:00'),
    (2, 'NUR-002', 'Pediatric Care', '15:00 - 23:00'),
    (6, 'NUR-003', 'Emergency Care', '23:00 - 07:00');

-- ── Workers ISA (1) ──────────────────────────────────────────
INSERT INTO Workers (staff_id, job_title, work_schedule) VALUES
    (3, 'Maintenance Technician', 'Sunday-Thursday 08:00-16:00');

-- ── Rooms (7) ────────────────────────────────────────────────
INSERT INTO Rooms (room_number, room_type_id, floor_number, capacity, [status], last_serviced) VALUES
    ('ICU-101', 1, 1, 1, 'Available',          '2026-03-01'),
    ('ICU-102', 1, 1, 1, 'Occupied',           '2026-02-28'),
    ('GW-201',  2, 2, 4, 'Available',          '2026-03-05'),
    ('GW-202',  2, 2, 4, 'Available',          '2026-03-04'),
    ('OR-301',  3, 3, 1, 'Available',          '2026-03-08'),
    ('LAB-401', 4, 4, 2, 'Available',          '2026-03-07'),
    ('PS-501',  5, 5, 1, 'Under Maintenance',  '2026-02-15');

-- ── Medicine (5) ─────────────────────────────────────────────
SET IDENTITY_INSERT Medicine ON;
INSERT INTO Medicine (medicine_id, [name], brand, [type], dosage, stock_quantity, [expiry_date]) VALUES
    (1, 'Lisinopril',  'Pharma Co.', 'Tablet',  '10mg',  1000, '2026-12-31'),
    (2, 'Paracetamol', 'Med Lab',    'Tablet',  '500mg', 2000, '2026-06-30'),
    (3, 'Amoxicillin', 'BioMed',     'Capsule', '250mg', 500,  '2026-09-15'),
    (4, 'Metformin',   'Diabetes',   'Tablet',  '500mg', 800,  '2027-01-20'),
    (5, 'Aspirin',     'Relief',     'Tablet',  '100mg', 1500, '2026-11-30');
SET IDENTITY_INSERT Medicine OFF;

-- ── Appointments (15) ────────────────────────────────────────
INSERT INTO Appointments (patient_id, doctor_id, department_id, appointment_date, appointment_time, purpose, [status]) VALUES
    -- Today
    (1,  1, 1, CAST(GETDATE() AS DATE),                     '10:00', 'Regular Check-up',     'Completed'),
    (2,  1, 1, CAST(GETDATE() AS DATE),                     '11:00', 'Follow-up',            'Scheduled'),
    (14, 3, 2, CAST(GETDATE() AS DATE),                     '09:00', 'Pediatric Consult',    'Scheduled'),
    -- Future
    (3,  3, 2, CAST(DATEADD(DAY,  1, GETDATE()) AS DATE),   '14:00', 'Initial Consultation', 'Scheduled'),
    (12, 5, 3, CAST(DATEADD(DAY,  3, GETDATE()) AS DATE),   '10:00', 'Knee Assessment',      'Scheduled'),
    -- Past week
    (4,  2, 1, CAST(DATEADD(DAY, -1, GETDATE()) AS DATE),   '09:00', 'Lab Review',           'Completed'),
    (1,  1, 1, CAST(DATEADD(DAY, -7, GETDATE()) AS DATE),   '10:00', 'Follow-up',            'Completed'),
    (1,  1, 1, CAST(DATEADD(DAY,-14, GETDATE()) AS DATE),   '10:00', 'Follow-up',            'Completed'),
    (5,  1, 1, CAST(DATEADD(DAY, -3, GETDATE()) AS DATE),   '15:00', 'Cardiac Follow-up',    'No Show'),
    (6,  3, 2, CAST(DATEADD(DAY, -5, GETDATE()) AS DATE),   '09:30', 'General Check-up',     'Completed'),
    (7,  9, 8, CAST(DATEADD(DAY, -2, GETDATE()) AS DATE),   '16:00', 'Asthma Emergency',     'Completed'),
    -- Older
    (4,  8, 7, CAST(DATEADD(DAY,-15, GETDATE()) AS DATE),   '08:00', 'Diabetes Check',       'Completed'),
    (4,  8, 7, CAST(DATEADD(DAY,-22, GETDATE()) AS DATE),   '08:00', 'Diabetes Check',       'Completed'),
    (15, 1, 1, CAST(DATEADD(DAY,-30, GETDATE()) AS DATE),   '11:00', 'CAD Follow-up',        'Completed'),
    (11, 5, 3, CAST(DATEADD(DAY,-10, GETDATE()) AS DATE),   '14:00', 'Arthritis Review',     'Completed');

-- ── Medical Records (5) ──────────────────────────────────────
SET IDENTITY_INSERT Medical_Records ON;
INSERT INTO Medical_Records (record_id, patient_id, doctor_id, appointment_id, record_date, diagnosis, treatment, prescription, lab_results_summary) VALUES
    (1, 1,  1, 1, GETDATE(),                  'Hypertension',         'Medication',          'Lisinopril 10mg daily',    'BP: 150/95, ECG: Normal sinus rhythm'),
    (2, 2,  1, 2, GETDATE(),                  'Migraine',             'Pain management',     'Paracetamol 500mg',         NULL),
    (3, 3,  3, 4, DATEADD(DAY, 1, GETDATE()), 'Routine check',       'None',                'Vitamins',                  'CBC: Normal range'),
    (4, 4,  2, 6, DATEADD(DAY,-1, GETDATE()), 'Diabetes Type 2',     'Medication adjusted', 'Metformin 500mg twice',     'HbA1c: 7.2%, Fasting: 145 mg/dL'),
    (5, 15, 1, 14,DATEADD(DAY,-30,GETDATE()), 'Coronary Artery Disease','Stent evaluation', 'Aspirin 100mg daily',       'Stress ECG: Abnormal, Troponin: Normal');
SET IDENTITY_INSERT Medical_Records OFF;

-- ── Billing (6) ──────────────────────────────────────────────
INSERT INTO Billing (patient_id, appointment_id, total_amount, paid_amount, payment_status, insurance_provider) VALUES
    (1,  1, 500.00,  500.00, 'Paid',           'NileCare Insurance'),
    (2,  2, 300.00,  0.00,   'Pending',         NULL),
    (3,  4, 750.00,  250.00, 'Partially Paid',  'EgyptHealth Plus'),
    (4,  6, 450.00,  450.00, 'Paid',            'CairoMed Insurance'),
    (15,14, 1200.00, 600.00, 'Partially Paid',  'SeniorCare Plan'),
    (11,15, 350.00,  350.00, 'Paid',            NULL);

-- ── Prescriptions (6) ───────────────────────────────────────
INSERT INTO Prescription (patient_id, doctor_id, record_id, prescription_date, medicine_id, dosage, frequency, duration, notes) VALUES
    (1,  1, 1, CAST(GETDATE() AS DATE),                     1, '10mg',  'Once daily',  '30 days', 'Take in the morning'),
    (1,  1, 1, CAST(GETDATE() AS DATE),                     5, '100mg', 'Once daily',  '30 days', 'Take with food'),
    (2,  1, 2, CAST(GETDATE() AS DATE),                     2, '500mg', 'As needed',   '7 days',  'Max 4 per day'),
    (4,  2, 4, CAST(DATEADD(DAY,-1,GETDATE()) AS DATE),     4, '500mg', 'Twice daily', '90 days', 'Monitor blood sugar'),
    (15, 1, 5, CAST(DATEADD(DAY,-30,GETDATE()) AS DATE),    5, '100mg', 'Once daily',  '365 days','Lifelong antiplatelet'),
    (4,  8, NULL, CAST(DATEADD(DAY,-15,GETDATE()) AS DATE), 4, '500mg', 'Twice daily', '90 days', 'Continued from prior visit');

-- ── Pharmacy dispensing (4) ──────────────────────────────────
INSERT INTO Pharmacy (medicine_id, patient_id, record_id, doctor_id, quantity) VALUES
    (1, 1,  1,    1, 30),
    (5, 1,  1,    1, 30),
    (2, 2,  2,    1, 14),
    (4, 4,  4,    2, 60);

-- ── Medical_Records_Medicine bridge (5) ──────────────────────
INSERT INTO Medical_Records_Medicine (record_id, medicine_id, dosage) VALUES
    (1, 1, '10mg daily'),
    (1, 5, '100mg daily'),
    (2, 2, '500mg as needed'),
    (4, 4, '500mg twice daily'),
    (5, 5, '100mg daily');

-- ── Ambulance (3) ────────────────────────────────────────────
INSERT INTO Ambulance (ambulance_number, [availability], driver_id, last_service_date) VALUES
    ('AMB-001', 'Available',   5, '2026-02-15'),
    ('AMB-002', 'Available',   NULL, '2026-01-20'),
    ('AMB-003', 'Maintenance', NULL, '2025-12-10');

-- ── Ambulance Log (2) ───────────────────────────────────────
INSERT INTO Ambulance_Log (ambulance_id, patient_id, pickup_location, dropoff_location, pickup_time, dropoff_time, [status]) VALUES
    (1, 7, 'Mansoura - Downtown', 'Hospital Main Entrance', DATEADD(HOUR,-2,GETDATE()), DATEADD(HOUR,-1,GETDATE()), 'Completed'),
    (1, 5, 'Cairo - Nasr City',   'Hospital Emergency',     DATEADD(DAY,-3,GETDATE()),  DATEADD(MINUTE,-150,DATEADD(DAY,-3,GETDATE())), 'Completed');

-- ── Room Assignments (3) ────────────────────────────────────
INSERT INTO Room_Assignments (room_id, staff_id, patient_id, assignment_type, assignment_date, end_date) VALUES
    (2, NULL, 1, 'Patient Admission', DATEADD(DAY,-2,GETDATE()), NULL),
    (1, 1,    NULL, 'Staff Shift',    GETDATE(), DATEADD(HOUR,8,GETDATE())),
    (3, NULL, 15,  'Patient Admission', DATEADD(DAY,-30,GETDATE()), DATEADD(DAY,-28,GETDATE()));

-- ── Cleaning Service (2) ────────────────────────────────────
INSERT INTO Cleaning_Service (room_id, staff_id, service_date, notes) VALUES
    (3, 3, CAST(GETDATE() AS DATE), 'Post-discharge deep clean'),
    (5, 3, CAST(DATEADD(DAY,-1,GETDATE()) AS DATE), 'Routine surgical suite sterilisation');

-- ── Blood Transfusion Log (1) ───────────────────────────────
INSERT INTO Blood_Transfusion_Log (blood_id, patient_id, doctor_id, record_id, quantity) VALUES
    (1, 15, 1, 5, 2);

COMMIT TRANSACTION;
PRINT '>> Comprehensive test data inserted successfully';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: PERFORMANCE INDEXES
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 3: ADDITIONAL PERFORMANCE INDEXES';
PRINT '═══════════════════════════════════════════════════════';
GO

-- Composite indexes for common join/filter patterns
CREATE NONCLUSTERED INDEX idx_appt_doctor_date ON Appointments(doctor_id, appointment_date) INCLUDE ([status]);
CREATE NONCLUSTERED INDEX idx_billing_patient   ON Billing(patient_id, created_at);
CREATE NONCLUSTERED INDEX idx_medrec_doctor     ON Medical_Records(doctor_id, record_date);
CREATE NONCLUSTERED INDEX idx_rx_medicine       ON Prescription(medicine_id, prescription_date);
CREATE NONCLUSTERED INDEX idx_pharmacy_medicine  ON Pharmacy(medicine_id);
CREATE NONCLUSTERED INDEX idx_transfusion_blood  ON Blood_Transfusion_Log(blood_id);

PRINT '>> Performance indexes created';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: ANALYTICAL VIEWS (10 Course-Required Queries)
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 4: 10 ANALYTICAL VIEWS';
PRINT '═══════════════════════════════════════════════════════';
GO

-- Q1: Patient Registry — newest registrations with computed age
CREATE VIEW vw_PatientRegistry AS
SELECT TOP 100
    patient_id,
    first_name + ' ' + last_name AS FullName,
    gender,
    date_of_birth,
    city,
    contact_number,
    created_at AS RegistrationDate,
    DATEDIFF(YEAR, date_of_birth, GETDATE())
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, date_of_birth, GETDATE()), date_of_birth) > GETDATE() THEN 1 ELSE 0 END
    AS PatientAge
FROM Patients
ORDER BY created_at DESC;
GO

-- Q2: Daily Doctor Schedule — today's appointments
CREATE VIEW vw_DailyDoctorSchedule AS
SELECT
    d.doctor_id        AS DoctorID,
    d.first_name + ' ' + d.last_name AS DoctorName,
    dept.department_name AS DepartmentName,
    a.appointment_time AS AppointmentTime,
    p.first_name + ' ' + p.last_name AS PatientName,
    a.[status]         AS AppointmentStatus
FROM Appointments a
INNER JOIN Doctors d     ON a.doctor_id     = d.doctor_id
INNER JOIN Departments dept ON a.department_id = dept.department_id
INNER JOIN Patients p    ON a.patient_id    = p.patient_id
WHERE a.appointment_date = CAST(GETDATE() AS DATE);
GO

-- Q3: No-Show Analysis — last 3 months by department
CREATE VIEW vw_NoShowAnalysis AS
SELECT
    dept.department_name AS DepartmentName,
    COUNT(*) AS TotalAppointments,
    COUNT(CASE WHEN a.[status] = 'No Show' THEN 1 END) AS NoShows,
    CAST(COUNT(CASE WHEN a.[status] = 'No Show' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS NoShowRate
FROM Appointments a
JOIN Departments dept ON a.department_id = dept.department_id
WHERE a.appointment_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY dept.department_name;
GO

-- Q4: Patient Visit Summary — complete visit history per patient
CREATE VIEW vw_PatientVisitSummary AS
SELECT
    p.first_name + ' ' + p.last_name AS PatientName,
    COUNT(DISTINCT a.appointment_id) AS TotalVisits,
    MAX(a.appointment_date) AS LastVisitDate,
    MAX(d.first_name + ' ' + d.last_name) AS LastDoctorSeen,
    MAX(mr.diagnosis) AS LastDiagnosis
FROM Patients p
LEFT JOIN Appointments a      ON p.patient_id = a.patient_id
LEFT JOIN Doctors d           ON a.doctor_id = d.doctor_id
LEFT JOIN Medical_Records mr  ON a.appointment_id = mr.appointment_id
GROUP BY p.patient_id, p.first_name, p.last_name;
GO

-- Q5: Frequent Visitors — >3 visits in last 6 months
CREATE VIEW vw_FrequentVisitors AS
SELECT
    p.first_name + ' ' + p.last_name AS PatientName,
    p.contact_number AS Phone,
    COUNT(a.appointment_id) AS TotalVisits,
    MAX(a.appointment_date) AS LastVisitDate
FROM Patients p
JOIN Appointments a ON p.patient_id = a.patient_id
WHERE a.appointment_date >= DATEADD(MONTH, -6, GETDATE())
GROUP BY p.patient_id, p.first_name, p.last_name, p.contact_number
HAVING COUNT(a.appointment_id) > 3;
GO

-- Q6: Top Medications — last 90 days with top-prescribing department
CREATE VIEW vw_TopMedications AS
WITH MedRanking AS (
    SELECT
        m.[name]           AS MedicationName,
        d.department_name  AS Department,
        COUNT(*)           AS Cnt,
        SUM(COUNT(*)) OVER(PARTITION BY m.[name]) AS Total,
        ROW_NUMBER() OVER(PARTITION BY m.[name] ORDER BY COUNT(*) DESC) AS Rn
    FROM Prescription pr
    INNER JOIN Medicine m     ON m.medicine_id = pr.medicine_id
    INNER JOIN Doctors doc    ON doc.doctor_id = pr.doctor_id
    INNER JOIN Departments d  ON d.department_id = doc.department_id
    WHERE pr.prescription_date >= DATEADD(DAY, -90, GETDATE())
    GROUP BY m.[name], d.department_name
)
SELECT TOP 10
    MedicationName,
    Total AS PrescriptionsCount,
    Department AS TopDepartment
FROM MedRanking
WHERE Rn = 1
ORDER BY Total DESC;
GO

-- Q7: Lab Results Documentation Rate — last 30 days by doctor
CREATE VIEW vw_LabResultsRate AS
SELECT
    doc.first_name + ' ' + doc.last_name AS DoctorName,
    COUNT(*) AS TotalRecords,
    COUNT(m.lab_results_summary) AS RecordsWithLabResults,
    CAST(COUNT(m.lab_results_summary) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS DocumentationRate
FROM Medical_Records m
JOIN Doctors doc ON doc.doctor_id = m.doctor_id
WHERE m.record_date >= DATEADD(DAY, -30, GETDATE())
GROUP BY doc.first_name, doc.last_name;
GO

-- Q8: Invoice Aging — unpaid invoices by age bucket
CREATE VIEW vw_InvoiceAging AS
SELECT
    CASE
        WHEN DATEDIFF(DAY, created_at, GETDATE()) <= 30 THEN '0-30 days'
        WHEN DATEDIFF(DAY, created_at, GETDATE()) <= 60 THEN '31-60 days'
        WHEN DATEDIFF(DAY, created_at, GETDATE()) <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END AS AgingBucket,
    COUNT(*) AS InvoiceCount,
    SUM(total_amount - ISNULL(paid_amount, 0)) AS TotalOutstanding
FROM Billing
WHERE payment_status IN ('Pending', 'Partially Paid')
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, created_at, GETDATE()) <= 30 THEN '0-30 days'
        WHEN DATEDIFF(DAY, created_at, GETDATE()) <= 60 THEN '31-60 days'
        WHEN DATEDIFF(DAY, created_at, GETDATE()) <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END;
GO

-- Q9: Monthly Revenue — last 12 months
CREATE VIEW vw_MonthlyRevenue AS
SELECT
    FORMAT(created_at, 'yyyy-MM') AS YearMonth,
    SUM(total_amount) AS TotalBilled,
    SUM(ISNULL(paid_amount, 0)) AS TotalPaid,
    SUM(total_amount - ISNULL(paid_amount, 0)) AS Outstanding,
    COUNT(bill_id) AS TotalInvoices
FROM Billing
WHERE created_at >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
GROUP BY FORMAT(created_at, 'yyyy-MM');
GO

-- Q10: Doctor Performance — last 30 days KPIs
CREATE VIEW vw_DoctorPerformance AS
SELECT
    doc.doctor_id AS DoctorID,
    doc.first_name + ' ' + doc.last_name AS DoctorName,
    d.department_name AS Department,
    doc.specialty,
    COUNT(DISTINCT a.appointment_id) AS TotalAppointments,
    COUNT(DISTINCT CASE WHEN a.[status] = 'Completed' THEN a.appointment_id END) AS CompletedVisits,
    COUNT(DISTINCT CASE WHEN a.[status] = 'No Show' THEN a.appointment_id END) AS NoShows,
    ISNULL(SUM(b.total_amount), 0) AS TotalBilledAmount
FROM Doctors doc
JOIN Departments d ON d.department_id = doc.department_id
LEFT JOIN Appointments a ON a.doctor_id = doc.doctor_id
    AND a.appointment_date >= DATEADD(DAY, -30, GETDATE())
LEFT JOIN Billing b ON b.appointment_id = a.appointment_id
GROUP BY doc.doctor_id, doc.first_name, doc.last_name, d.department_name, doc.specialty;
GO

PRINT '>> All 10 analytical views created';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: ROLE-BASED ACCESS CONTROL (6 Roles)
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 5: ROLE-BASED ACCESS CONTROL';
PRINT '═══════════════════════════════════════════════════════';
GO

CREATE ROLE HospRole_Doctor;
CREATE ROLE HospRole_Nurse;
CREATE ROLE HospRole_Receptionist;      -- [IMP-22]
CREATE ROLE HospRole_Accountant;
CREATE ROLE HospRole_Admin;
CREATE ROLE HospRole_Patient;
GO

-- ── DOCTOR ROLE — Medical data only, NO billing ──────────────
GRANT SELECT ON Patients         TO HospRole_Doctor;
GRANT SELECT ON Appointments     TO HospRole_Doctor;
GRANT SELECT ON Medical_Records  TO HospRole_Doctor;
GRANT SELECT ON Prescription     TO HospRole_Doctor;
GRANT SELECT ON Medicine         TO HospRole_Doctor;
GRANT SELECT ON Pharmacy         TO HospRole_Doctor;
GRANT SELECT ON Doctors          TO HospRole_Doctor;
GRANT SELECT ON Departments      TO HospRole_Doctor;
GRANT SELECT ON Blood_Bank       TO HospRole_Doctor;
GRANT INSERT, UPDATE ON Medical_Records TO HospRole_Doctor;
GRANT INSERT, UPDATE ON Prescription    TO HospRole_Doctor;
GRANT INSERT ON Appointments            TO HospRole_Doctor;
GRANT SELECT ON vw_PatientRegistry      TO HospRole_Doctor;
GRANT SELECT ON vw_DailyDoctorSchedule  TO HospRole_Doctor;
GRANT SELECT ON vw_PatientVisitSummary  TO HospRole_Doctor;
GRANT SELECT ON vw_DoctorPerformance    TO HospRole_Doctor;
DENY  SELECT ON Billing                 TO HospRole_Doctor;

-- ── NURSE ROLE — Patient care & rooms, NO billing or records ─
GRANT SELECT ON Patients          TO HospRole_Nurse;
GRANT SELECT ON Staff             TO HospRole_Nurse;
GRANT SELECT ON Nurses            TO HospRole_Nurse;
GRANT SELECT ON Rooms             TO HospRole_Nurse;
GRANT SELECT ON Room_Types        TO HospRole_Nurse;
GRANT SELECT ON Room_Assignments  TO HospRole_Nurse;
GRANT SELECT ON Cleaning_Service  TO HospRole_Nurse;
GRANT SELECT ON Departments       TO HospRole_Nurse;
GRANT SELECT ON Blood_Bank        TO HospRole_Nurse;
GRANT INSERT, UPDATE ON Room_Assignments TO HospRole_Nurse;
GRANT INSERT ON Cleaning_Service         TO HospRole_Nurse;
GRANT SELECT ON vw_PatientRegistry       TO HospRole_Nurse;
DENY  SELECT ON Billing                  TO HospRole_Nurse;
DENY  SELECT ON Medical_Records          TO HospRole_Nurse;
DENY  SELECT ON Prescription             TO HospRole_Nurse;

-- ── RECEPTIONIST ROLE — Scheduling & patient info ────────────
GRANT SELECT ON Patients              TO HospRole_Receptionist;
GRANT SELECT ON Doctors               TO HospRole_Receptionist;
GRANT SELECT ON Departments           TO HospRole_Receptionist;
GRANT SELECT, INSERT, UPDATE ON Appointments TO HospRole_Receptionist;
GRANT SELECT ON vw_PatientRegistry         TO HospRole_Receptionist;
GRANT SELECT ON vw_DailyDoctorSchedule     TO HospRole_Receptionist;
DENY  SELECT ON Medical_Records            TO HospRole_Receptionist;
DENY  SELECT ON Prescription               TO HospRole_Receptionist;
DENY  SELECT ON Billing                    TO HospRole_Receptionist;

-- ── ACCOUNTANT ROLE — Billing ONLY, NO medical data ──────────
GRANT SELECT ON Billing          TO HospRole_Accountant;
GRANT SELECT ON Appointments     TO HospRole_Accountant;
GRANT SELECT ON Patients         TO HospRole_Accountant;
GRANT UPDATE ON Billing          TO HospRole_Accountant;
GRANT SELECT ON vw_InvoiceAging  TO HospRole_Accountant;
GRANT SELECT ON vw_MonthlyRevenue TO HospRole_Accountant;
DENY  SELECT ON Medical_Records  TO HospRole_Accountant;
DENY  SELECT ON Prescription     TO HospRole_Accountant;

-- ── ADMIN ROLE — Full database control ───────────────────────
GRANT CONTROL ON DATABASE::HospitalManagementDB TO HospRole_Admin;

-- ── PATIENT ROLE — Own records only (simplified; RLS in v2) ──
GRANT SELECT ON vw_PatientRegistry TO HospRole_Patient;

PRINT '>> 6 security roles created and configured';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: STORED PROCEDURES (6 Procedures)
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 6: STORED PROCEDURES';
PRINT '═══════════════════════════════════════════════════════';
GO

-- SP1: Book Appointment (with validation)
CREATE PROCEDURE sp_BookAppointment
    @PatientID       INT,
    @DoctorID        INT,
    @DepartmentID    INT,
    @AppointmentDate DATE,
    @AppointmentTime TIME,
    @Purpose         NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Patients WHERE patient_id = @PatientID AND is_active = 1)
        BEGIN SELECT 'ERROR' AS Result, 'Patient not found or inactive' AS Message; RETURN; END

        IF NOT EXISTS (SELECT 1 FROM Doctors WHERE doctor_id = @DoctorID AND is_active = 1)
        BEGIN SELECT 'ERROR' AS Result, 'Doctor not found or inactive' AS Message; RETURN; END

        IF NOT EXISTS (SELECT 1 FROM Departments WHERE department_id = @DepartmentID AND is_active = 1)
        BEGIN SELECT 'ERROR' AS Result, 'Department not found or inactive' AS Message; RETURN; END

        IF @AppointmentDate < CAST(GETDATE() AS DATE)
        BEGIN SELECT 'ERROR' AS Result, 'Cannot book appointments in the past' AS Message; RETURN; END

        INSERT INTO Appointments (patient_id, doctor_id, department_id, appointment_date, appointment_time, purpose, [status])
        VALUES (@PatientID, @DoctorID, @DepartmentID, @AppointmentDate, @AppointmentTime, @Purpose, 'Scheduled');

        SELECT 'SUCCESS' AS Result, SCOPE_IDENTITY() AS AppointmentID;
    END TRY
    BEGIN CATCH
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- SP2: Create Medical Record (with appointment status update)
CREATE PROCEDURE sp_CreateMedicalRecord
    @PatientID     INT,
    @DoctorID      INT,
    @AppointmentID INT,
    @Diagnosis     NVARCHAR(MAX),
    @Treatment     NVARCHAR(MAX),
    @Prescription  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Appointments WHERE appointment_id = @AppointmentID)
        BEGIN SELECT 'ERROR' AS Result, 'Appointment not found' AS Message; RETURN; END

        INSERT INTO Medical_Records (patient_id, doctor_id, appointment_id, record_date, diagnosis, treatment, prescription)
        VALUES (@PatientID, @DoctorID, @AppointmentID, GETDATE(), @Diagnosis, @Treatment, @Prescription);

        UPDATE Appointments SET [status] = 'Completed', updated_at = GETDATE()
        WHERE appointment_id = @AppointmentID;

        SELECT 'SUCCESS' AS Result, SCOPE_IDENTITY() AS RecordID;
    END TRY
    BEGIN CATCH
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- SP3: Process Payment (cumulative tracking)
CREATE PROCEDURE sp_ProcessPayment
    @BillID        INT,
    @PaymentAmount DECIMAL(10,2),
    @PaymentDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @TotalAmount DECIMAL(10,2), @CurrentPaid DECIMAL(10,2), @NewPaid DECIMAL(10,2);

        SELECT @TotalAmount = total_amount, @CurrentPaid = ISNULL(paid_amount, 0)
        FROM Billing WHERE bill_id = @BillID;

        IF @TotalAmount IS NULL
        BEGIN SELECT 'ERROR' AS Result, 'Bill not found' AS Message; RETURN; END

        IF @PaymentAmount <= 0
        BEGIN SELECT 'ERROR' AS Result, 'Payment amount must be positive' AS Message; RETURN; END

        SET @NewPaid = @CurrentPaid + @PaymentAmount;

        UPDATE Billing
        SET paid_amount = @NewPaid,
            payment_status = CASE
                WHEN @NewPaid >= total_amount THEN 'Paid'
                WHEN @NewPaid > 0 THEN 'Partially Paid'
                ELSE 'Pending' END,
            payment_date = @PaymentDate
        WHERE bill_id = @BillID;

        SELECT 'SUCCESS' AS Result, @NewPaid AS TotalPaidSoFar, (@TotalAmount - @NewPaid) AS RemainingBalance;
    END TRY
    BEGIN CATCH
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- SP4: Register New Patient
CREATE PROCEDURE sp_RegisterPatient
    @FirstName      NVARCHAR(50),
    @LastName       NVARCHAR(50),
    @NationalID     NVARCHAR(20),
    @DateOfBirth    DATE,
    @Gender         CHAR(1),
    @BloodGroup     VARCHAR(5) = NULL,
    @ContactNumber  NVARCHAR(15) = NULL,
    @Email          NVARCHAR(100) = NULL,
    @City           NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Patients WHERE national_id = @NationalID)
        BEGIN SELECT 'ERROR' AS Result, 'National ID already registered' AS Message; RETURN; END

        INSERT INTO Patients (first_name, last_name, national_id, date_of_birth, gender, blood_group, contact_number, email, city)
        VALUES (@FirstName, @LastName, @NationalID, @DateOfBirth, @Gender, @BloodGroup, @ContactNumber, @Email, @City);

        SELECT 'SUCCESS' AS Result, SCOPE_IDENTITY() AS PatientID;
    END TRY
    BEGIN CATCH
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- SP5: Generate Billing for Appointment
CREATE PROCEDURE sp_GenerateBill
    @PatientID     INT,
    @AppointmentID INT,
    @TotalAmount   DECIMAL(10,2),
    @InsuranceProvider NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Patients WHERE patient_id = @PatientID)
        BEGIN SELECT 'ERROR' AS Result, 'Patient not found' AS Message; RETURN; END

        IF @AppointmentID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Appointments WHERE appointment_id = @AppointmentID)
        BEGIN SELECT 'ERROR' AS Result, 'Appointment not found' AS Message; RETURN; END

        INSERT INTO Billing (patient_id, appointment_id, total_amount, paid_amount, payment_status, insurance_provider)
        VALUES (@PatientID, @AppointmentID, @TotalAmount, 0, 'Pending', @InsuranceProvider);

        SELECT 'SUCCESS' AS Result, SCOPE_IDENTITY() AS BillID,
               'INV-' + CAST(SCOPE_IDENTITY() AS VARCHAR(10)) AS InvoiceNumber;
    END TRY
    BEGIN CATCH
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- SP6: Cancel Appointment
CREATE PROCEDURE sp_CancelAppointment
    @AppointmentID INT,
    @Reason        NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CurrentStatus NVARCHAR(20);
        SELECT @CurrentStatus = [status] FROM Appointments WHERE appointment_id = @AppointmentID;

        IF @CurrentStatus IS NULL
        BEGIN SELECT 'ERROR' AS Result, 'Appointment not found' AS Message; RETURN; END

        IF @CurrentStatus IN ('Completed', 'Cancelled')
        BEGIN SELECT 'ERROR' AS Result, 'Cannot cancel a ' + @CurrentStatus + ' appointment' AS Message; RETURN; END

        UPDATE Appointments
        SET [status] = 'Cancelled', updated_at = GETDATE(), purpose = ISNULL(purpose,'') + ' [CANCELLED: ' + ISNULL(@Reason,'No reason') + ']'
        WHERE appointment_id = @AppointmentID;

        SELECT 'SUCCESS' AS Result, 'Appointment cancelled' AS Message;
    END TRY
    BEGIN CATCH
        SELECT 'ERROR' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

PRINT '>> 6 stored procedures created';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7: TRIGGERS (3 Triggers)
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 7: TRIGGERS';
PRINT '═══════════════════════════════════════════════════════';
GO

-- TR1: Auto-update updated_at timestamp on Patient modification
CREATE TRIGGER trg_Patients_UpdateTimestamp
ON Patients
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p SET p.updated_at = GETDATE()
    FROM Patients p INNER JOIN inserted i ON p.patient_id = i.patient_id;
END;
GO

-- TR2: Auto-update updated_at on Appointments modification
CREATE TRIGGER trg_Appointments_UpdateTimestamp
ON Appointments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a SET a.updated_at = GETDATE()
    FROM Appointments a INNER JOIN inserted i ON a.appointment_id = i.appointment_id;
END;
GO

-- TR3: Prevent dispensing expired medicine
CREATE TRIGGER trg_Pharmacy_PreventExpired
ON Pharmacy
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Medicine m ON i.medicine_id = m.medicine_id
        WHERE m.expiry_date < CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR('Cannot dispense expired medication. Check medicine expiry dates.', 16, 1);
        RETURN;
    END

    -- If all valid, perform the insert
    INSERT INTO Pharmacy (medicine_id, patient_id, record_id, doctor_id, quantity, prescription_date)
    SELECT medicine_id, patient_id, record_id, doctor_id, quantity, prescription_date FROM inserted;
END;
GO

PRINT '>> 3 triggers created';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8: AUDIT & MONITORING VIEWS
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '═══════════════════════════════════════════════════════';
PRINT '  SECTION 8: AUDIT & MONITORING VIEWS';
PRINT '═══════════════════════════════════════════════════════';
GO

-- Role membership audit
CREATE VIEW vw_RoleMemberships AS
SELECT
    r.name AS RoleName,
    m.name AS MemberName,
    CASE m.type WHEN 'U' THEN 'User' WHEN 'R' THEN 'Role' END AS MemberType
FROM sys.database_principals r
INNER JOIN sys.database_role_members rm ON r.principal_id = rm.role_principal_id
INNER JOIN sys.database_principals m   ON m.principal_id = rm.member_principal_id
WHERE r.type = 'R';
GO

-- Table permission audit
CREATE VIEW vw_TablePermissions AS
SELECT
    OBJECT_NAME(major_id)        AS TableName,
    USER_NAME(grantee_principal_id) AS RoleName,
    permission_name              AS Permission,
    state_desc                   AS PermissionState
FROM sys.database_permissions
WHERE major_id IS NOT NULL AND class = 1;
GO

PRINT '>> Audit views created';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 9: FINAL STATUS REPORT
-- ═══════════════════════════════════════════════════════════════════════════

PRINT '';
PRINT '════════════════════════════════════════════════════════════';
PRINT '  HOSPITAL MANAGEMENT DATABASE — SETUP COMPLETE';
PRINT '════════════════════════════════════════════════════════════';
PRINT '  DATABASE : HospitalManagementDB v2.0';
PRINT '  STATUS   : Production Ready (Improved)';
PRINT '';
PRINT '  COMPONENTS:';
PRINT '    22 Tables with relationships, constraints & indexes';
PRINT '    Test Data: 20 patients, 10 doctors, 8 staff, 15 appointments';
PRINT '    10 Analytical Views (Business Intelligence)';
PRINT '    6 Security Roles (Doctor, Nurse, Receptionist, Accountant, Admin, Patient)';
PRINT '    6 Stored Procedures (CRUD Operations)';
PRINT '    3 Triggers (Timestamp auto-update, expired medicine prevention)';
PRINT '    2 Audit/Monitoring Views';
PRINT '';
PRINT '  SECURITY ARCHITECTURE:';
PRINT '    Doctor       -> Medical records (NOT invoices)';
PRINT '    Nurse        -> Room assignments (NOT billing/records)';
PRINT '    Receptionist -> Appointments (NOT billing/records)';
PRINT '    Accountant   -> Billing ONLY (NOT medical data)';
PRINT '    Admin        -> Full database access';
PRINT '    Patient      -> Own records only (RLS in v2)';
PRINT '';
PRINT '  READY FOR SUBMISSION';
PRINT '════════════════════════════════════════════════════════════';
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- SAMPLE TEST SCRIPTS (UNCOMMENT TO RUN)
-- ═══════════════════════════════════════════════════════════════════════════

/*
-- ── Views ────────────────────────────────────────────────────
SELECT * FROM vw_PatientRegistry;
SELECT * FROM vw_DailyDoctorSchedule;
SELECT * FROM vw_NoShowAnalysis;
SELECT * FROM vw_PatientVisitSummary;
SELECT * FROM vw_FrequentVisitors;
SELECT * FROM vw_TopMedications;
SELECT * FROM vw_LabResultsRate;
SELECT * FROM vw_InvoiceAging;
SELECT * FROM vw_MonthlyRevenue;
SELECT * FROM vw_DoctorPerformance;

-- ── Stored Procedures ────────────────────────────────────────
-- Register a new patient
EXEC sp_RegisterPatient
    @FirstName = 'Nadia', @LastName = 'Youssef',
    @NationalID = '29501011234599', @DateOfBirth = '1995-01-01',
    @Gender = 'F', @BloodGroup = 'O+', @City = 'Cairo';

-- Book an appointment
EXEC sp_BookAppointment
    @PatientID = 5, @DoctorID = 1, @DepartmentID = 1,
    @AppointmentDate = '2026-03-20', @AppointmentTime = '14:00',
    @Purpose = 'Follow-up visit';

-- Create medical record
EXEC sp_CreateMedicalRecord
    @PatientID = 1, @DoctorID = 1, @AppointmentID = 1,
    @Diagnosis = 'High Blood Pressure',
    @Treatment = 'Medication prescribed',
    @Prescription = 'Lisinopril 10mg daily';

-- Generate a bill
EXEC sp_GenerateBill
    @PatientID = 1, @AppointmentID = 1,
    @TotalAmount = 500.00, @InsuranceProvider = 'NileCare';

-- Process payment
EXEC sp_ProcessPayment
    @BillID = 3, @PaymentAmount = 200.00, @PaymentDate = GETDATE();

-- Cancel appointment
EXEC sp_CancelAppointment
    @AppointmentID = 2, @Reason = 'Patient requested reschedule';

-- ── Audit ────────────────────────────────────────────────────
SELECT * FROM vw_RoleMemberships;
SELECT * FROM vw_TablePermissions;
*/
