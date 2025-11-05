
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'StudentPerformanceDB')
BEGIN
    ALTER DATABASE StudentPerformanceDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE StudentPerformanceDB;
END
GO


CREATE DATABASE StudentPerformanceDB;
GO
USE StudentPerformanceDB;
GO


CREATE TABLE dbo.Students (
    StudentID INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Class NVARCHAR(20) NOT NULL,
    Gender NVARCHAR(10) NULL
);

CREATE TABLE dbo.Subjects (
    SubjectID INT IDENTITY(1,1) PRIMARY KEY,
    SubjectName NVARCHAR(50) NOT NULL
);

CREATE TABLE dbo.Marks (
    MarkID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID INT NOT NULL,
    SubjectID INT NOT NULL,
    MarksObtained DECIMAL(7,2) NOT NULL,
    TotalMarks DECIMAL(7,2) NOT NULL,
    ExamDate DATE NULL,
    CONSTRAINT FK_Marks_Students FOREIGN KEY (StudentID) REFERENCES dbo.Students(StudentID),
    CONSTRAINT FK_Marks_Subjects FOREIGN KEY (SubjectID) REFERENCES dbo.Subjects(SubjectID)
);

CREATE TABLE dbo.Attendance (
    AttendanceID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    Status NVARCHAR(10) NOT NULL, -- 'Present' or 'Absent'
    CONSTRAINT FK_Attendance_Students FOREIGN KEY (StudentID) REFERENCES dbo.Students(StudentID)
);
GO


CREATE INDEX IX_Marks_StudentID ON dbo.Marks(StudentID);
CREATE INDEX IX_Marks_SubjectID ON dbo.Marks(SubjectID);
CREATE INDEX IX_Attendance_StudentID ON dbo.Attendance(StudentID);
GO


INSERT INTO dbo.Students (FullName, Class, Gender) VALUES
('Alice Johnson', '10A', 'Female'),
('Bob Smith', '10A', 'Male'),
('Charlie Brown', '10A', 'Male'),
('Diana Prince', '10A', 'Female');

INSERT INTO dbo.Subjects (SubjectName) VALUES
('Math'), ('Science'), ('English');


INSERT INTO dbo.Marks (StudentID, SubjectID, MarksObtained, TotalMarks, ExamDate) VALUES
(1,1,85,100,'2025-09-10'),
(1,2,90,100,'2025-09-10'),
(1,3,78,100,'2025-09-10'),
(2,1,55,100,'2025-09-10'),
(2,2,60,100,'2025-09-10'),
(2,3,50,100,'2025-09-10'),
(3,1,35,100,'2025-09-10'),
(3,2,40,100,'2025-09-10'),
(3,3,45,100,'2025-09-10'),
(4,1,92,100,'2025-09-10'),
(4,2,88,100,'2025-09-10'),
(4,3,95,100,'2025-09-10');


INSERT INTO dbo.Attendance (StudentID, AttendanceDate, Status) VALUES
(1,'2025-09-01','Present'), (1,'2025-09-02','Present'), (1,'2025-09-03','Absent'),
(2,'2025-09-01','Present'), (2,'2025-09-02','Absent'),  (2,'2025-09-03','Present'),
(3,'2025-09-01','Absent'),  (3,'2025-09-02','Present'), (3,'2025-09-03','Absent'),
(4,'2025-09-01','Present'), (4,'2025-09-02','Present'), (4,'2025-09-03','Present');
GO

IF OBJECT_ID('dbo.vw_StudentPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_StudentPerformance;
GO

CREATE VIEW dbo.vw_StudentPerformance
AS
SELECT
    s.StudentID,
    s.FullName,
    s.Class,
   
    CAST(ROUND(AVG(m.MarksObtained), 2) AS DECIMAL(7,2)) AS AvgMarks,
   
    CAST(ROUND(
        CASE WHEN SUM(m.TotalMarks) = 0 THEN 0
             ELSE (SUM(m.MarksObtained) * 1.0 / NULLIF(SUM(m.TotalMarks),0)) * 100.0
        END, 2) AS DECIMAL(7,2)
    ) AS Percentage,
   
    CASE 
        WHEN (SUM(m.TotalMarks) = 0) THEN 'NoMarks'
        WHEN (SUM(m.MarksObtained) * 1.0 / NULLIF(SUM(m.TotalMarks),0) * 100.0) >= 75 THEN 'Distinction'
        WHEN (SUM(m.MarksObtained) * 1.0 / NULLIF(SUM(m.TotalMarks),0) * 100.0) >= 50 THEN 'Pass'
        ELSE 'Fail'
    END AS Result
FROM dbo.Students s
LEFT JOIN dbo.Marks m ON s.StudentID = m.StudentID
GROUP BY s.StudentID, s.FullName, s.Class;
GO


IF OBJECT_ID('dbo.vw_AttendanceRate', 'V') IS NOT NULL
    DROP VIEW dbo.vw_AttendanceRate;
GO

CREATE VIEW dbo.vw_AttendanceRate
AS
SELECT
    s.StudentID,
    s.FullName,

    COUNT(CASE WHEN a.Status = 'Present' THEN 1 END) AS DaysPresent,
    COUNT(*) AS TotalDays,
    
    CAST(ROUND(
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE (COUNT(CASE WHEN a.Status = 'Present' THEN 1 END) * 100.0 / COUNT(*))
        END, 2) AS DECIMAL(7,2)
    ) AS AttendanceRate
FROM dbo.Students s
LEFT JOIN dbo.Attendance a ON s.StudentID = a.StudentID
GROUP BY s.StudentID, s.FullName;
GO

IF OBJECT_ID('dbo.vw_StudentDashboard','V') IS NOT NULL
    DROP VIEW dbo.vw_StudentDashboard;
GO

CREATE VIEW dbo.vw_StudentDashboard
AS
SELECT
    p.StudentID,
    p.FullName,
    p.Class,
    p.AvgMarks,
    p.Percentage,
    p.Result,
    a.DaysPresent,
    a.TotalDays,
    a.AttendanceRate
FROM dbo.vw_StudentPerformance p
LEFT JOIN dbo.vw_AttendanceRate a ON p.StudentID = a.StudentID;
GO

PRINT '--- Full Student Dashboard ---';
SELECT * FROM dbo.vw_StudentDashboard ORDER BY StudentID;
GO


PRINT '--- Count by Result (Pass/Fail/Distinction) ---';
SELECT Result, COUNT(*) AS StudentCount
FROM dbo.vw_StudentPerformance
GROUP BY Result;
GO


PRINT '--- Attendance Ranking ---';
SELECT FullName, AttendanceRate, DaysPresent, TotalDays
FROM dbo.vw_StudentDashboard
ORDER BY AttendanceRate DESC, FullName;
GO

PRINT '--- Top Performers (by Percentage) ---';
SELECT TOP (10) FullName, Percentage, AvgMarks, Result
FROM dbo.vw_StudentDashboard
ORDER BY Percentage DESC, AvgMarks DESC;
GO


PRINT '--- Per-Subject Average Marks ---';
SELECT sub.SubjectName,
       CAST(ROUND(AVG(m.MarksObtained),2) AS DECIMAL(7,2)) AS AvgMarksPerSubject,
       COUNT(*) AS ExamRows 
FROM dbo.Marks m
JOIN dbo.Subjects sub ON m.SubjectID = sub.SubjectID
GROUP BY sub.SubjectName
ORDER BY sub.SubjectName;
GO


