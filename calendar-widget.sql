CREATE FUNCTION dbo.fn_easterSunday(@year smallint)
RETURNS date
WITH SCHEMABINDING
AS

--- Calculates the date of easter sunday for a given year, using
--- the Meeus-Jones-Butcher algorithm.
---
--- Source: http://en.wikipedia.org/wiki/Computus

BEGIN;

    --- Variables used:
    DECLARE @a tinyint, @b tinyint, @c tinyint,
            @d tinyint, @e tinyint, @f tinyint,
            @g tinyint, @h tinyint, @i tinyint,
            @k tinyint, @l tinyint, @m tinyint,
            @date date;

    --- Calculation steps:
    SELECT @a=@year%19, @b=FLOOR(1.0*@year/100), @c=@year%100;
    SELECT @d=FLOOR(1.0*@b/4), @e=@b%4, @f=FLOOR((8.0+@b)/25);
    SELECT @g=FLOOR((1.0+@b-@f)/3);
    SELECT @h=(19*@a+@b-@d-@g+15)%30, @i=FLOOR(1.0*@c/4), @k=@year%4;
    SELECT @l=(32.0+2*@e+2*@i-@h-@k)%7;
    SELECT @m=FLOOR((1.0*@a+11*@h+22*@l)/451);
    SELECT @date=
        DATEADD(dd, (@h+@l-7*@m+114)%31,
            DATEADD(mm, FLOOR((1.0*@h+@l-7*@m+114)/31)-1,
                DATEADD(yy, @year-2000, {d '2000-01-01'})
            )
        );

    --- Return the output date:
    RETURN @date;
END;
GO

CREATE PROCEDURE dbo.CalendarWidget(@inputYear NVARCHAR(4), @numofyears INT) AS
DECLARE @dayofyear INT
DECLARE @StartDate NVARCHAR(8)
DECLARE @CurrentDate DATE
DECLARE @YearIncrement INT
DECLARE @daymax INT
DECLARE @PublicHoliday BIT
DECLARE @PublicHolidayName NVARCHAR(50)
DECLARE @Weekend BIT
DECLARE @NameOfDay NVARCHAR(10)
DECLARE @NameOfMonth NVARCHAR(10)
DECLARE @CalendarMonth INT
DECLARE @CalendarYear INT
DECLARE @CalendarWeek INT
DECLARE @NYSet BIT
DECLARE @XMasSet BIT
DECLARE @BoxSet BIT
DECLARE @CalendarMonthStart DATE
DECLARE @CalendarMonthEnd DATE
BEGIN;
IF OBJECT_ID('dbo.CalendarLookup', 'U') IS NOT NULL
  DROP TABLE dbo.CalendarLookup; 

CREATE TABLE dbo.CalendarLookup (
CalendarDate DATE PRIMARY KEY NOT NULL,
PublicHoliday BIT NOT NULL DEFAULT 0,
PublicHolidayName NVARCHAR(50),
Weekend BIT NOT NULL DEFAULT 0,
NameOfDay NVARCHAR(10),
NameOfMonth NVARCHAR(10),
CalendarMonth INT,
CalendarYear INT,
CalendarWeek INT,
CalendarMonthStart DATE,
CalendarMonthEnd DATE,
CalendarYearStart DATE,
CalendarYearEnd DATE);
SET @YearIncrement = 0;
WHILE @YearIncrement <= @numofyears
BEGIN;
	SET @dayofyear = 0;
	SET @StartDate = @inputYear + '0101';
	IF CAST(@inputYear as INT) % 4 = 0 SET @daymax = 365 ELSE SET @daymax = 364;
	PRINT @daymax;
	SET @NYSet = 0;
	SET @XMasSet = 0;
	SET @BoxSet = 0;
	WHILE @dayofyear <= @daymax
	BEGIN;
		SET @CurrentDate = DATEADD(DAY,@dayofyear,@StartDate);
		IF DATEPART(day,@CurrentDate) = 1 
			BEGIN
			SET @CalendarMonthStart = @CurrentDate
			IF DATEPART(month,@CurrentDate) IN (1,3,5,7,8,10,12)
			SET @CalendarMonthEnd = DATEADD(day,30,@CurrentDate)
			ELSE IF DATEPART(month,@CurrentDate) IN (4,6,9,11)
			SET @CalendarMonthEnd = DATEADD(day,29,@CurrentDate)
			ELSE IF DATEPART(month,@CurrentDate) = 2 AND DATEPART(year,@CurrentDate) % 4 = 0
			SET @CalendarMonthEnd = DATEADD(day,28,@CurrentDate)
			ELSE SET @CalendarMonthEnd = DATEADD(day,27,@CurrentDate)
			END
		SET @PublicHolidayName = NULL;
		IF @dayofyear <= 6 AND @NYSet = 0 AND DATENAME(weekday,@CurrentDate) IN ('Monday','Tuesday','Wednesday','Thursday','Friday')
			BEGIN
				SET @PublicHoliday = 1;
				IF @dayofyear = 0 SET @PublicHolidayName = 'New Years Day' ELSE SET @PublicHolidayName = 'New Years Day (Substitute)';
				IF @dayofyear > 0 UPDATE dbo.CalendarLookup SET PublicHolidayName = 'New Years Day' WHERE CalendarDate = DATEADD(day,-@dayofyear,@CurrentDate);
				SET @NYSet = 1;
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		IF @PublicHolidayName IS NULL
		BEGIN
		IF @CurrentDate = dbo.fn_easterSunday(@inputYear)
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = 'Easter Sunday'
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
		IF DATEADD(day,2,@CurrentDate) = dbo.fn_easterSunday(@inputYear)
			BEGIN
				SET @PublicHoliday = 1;
				SET @PublicHolidayName = 'Good Friday'
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
		IF DATEADD(day,-1,@CurrentDate) = dbo.fn_easterSunday(@inputYear)
			BEGIN
				SET @PublicHoliday = 1;
				SET @PublicHolidayName = 'Easter Monday'
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
		IF DATEPART(month,@CurrentDate) = 12 and DATEPART(day,@CurrentDate) BETWEEN 25 AND 27 AND DATENAME(weekday,@CurrentDate) IN ('Monday','Tuesday','Wednesday','Thursday','Friday') AND @XMasSet = 0
			BEGIN
			SET @PublicHoliday = 1;
			IF DATEPART(day,@CurrentDate) = 25 SET @PublicHolidayName = 'Chirstmas Day' ELSE SET @PublicHolidayName = 'Christmas Day (Substitute)'
			IF DATEPART(day,@CurrentDate) > 25 UPDATE dbo.CalendarLookup SET PublicHolidayName = 'Christmas Day' WHERE CalendarDate = DATEADD(day,-(DATEPART(day,@CurrentDate)-25),@CurrentDate)
			SET @XMasSet = 1;
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
		IF DATEPART(month,@CurrentDate) = 12 and DATEPART(day,@CurrentDate) BETWEEN 26 AND 28 AND DATENAME(weekday,@CurrentDate) IN ('Tuesday','Wednesday','Thursday','Friday') AND @BoxSet = 0 AND @XmasSet = 1
			BEGIN
			SET @PublicHoliday = 1;
			IF DATEPART(day,@CurrentDate) = 26 SET @PublicHolidayName = 'Boxing Day' ELSE SET @PublicHolidayName = 'Boxing Day (Substitute)'
			IF DATEPART(day,@CurrentDate) > 26 AND DATENAME(weekday,DATEADD(day,-(DATEPART(day,@CurrentDate)-26),@CurrentDate)) IN ('Satuday','Sunday') UPDATE dbo.CalendarLookup SET PublicHolidayName = 'Boxing Day' WHERE CalendarDate = DATEADD(day,-(DATEPART(day,@CurrentDate)-26),@CurrentDate)
			SET @BoxSet = 1;
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
			IF DATEPART(month,@CurrentDate) = 5 AND DATEPART(day,@CurrentDate) BETWEEN 1 AND 7 AND DATENAME(weekday,@CurrentDate) = 'Monday'
			BEGIN
			SET @PublicHoliday = 1;
			SET @PublicHolidayName = 'May Day'
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
			IF DATEPART(month,@CurrentDate) = 5 AND DATEPART(day,@CurrentDate) BETWEEN 25 AND 31 AND DATENAME(weekday,@CurrentDate) = 'Monday'
			BEGIN
			SET @PublicHoliday = 1;
			SET @PublicHolidayName = 'Spring Bank Holiday'
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		IF @PublicHolidayName IS NULL
		BEGIN
			IF DATEPART(month,@CurrentDate) = 8 AND DATEPART(day,@CurrentDate) BETWEEN 25 AND 31 AND DATENAME(weekday,@CurrentDate) = 'Monday'
			BEGIN
			SET @PublicHoliday = 1;
			SET @PublicHolidayName = 'Late Summer Bank Holiday'
			END
		ELSE
			BEGIN
				SET @PublicHoliday = 0;
				SET @PublicHolidayName = NULL;
			END
		END
		SET @NameOfDay = DATENAME(weekday,@CurrentDate); 
		IF @NameOfDay IN ('Saturday','Sunday') SET @Weekend = 1 ELSE SET @Weekend = 0
		SET @NameOfMonth = DATENAME(month,@CurrentDate);
		INSERT INTO dbo.CalendarLookup(CalendarDate, PublicHoliday, PublicHolidayName, Weekend, NameOfDay, NameOfMonth, CalendarMonth, CalendarYear, CalendarWeek, CalendarMonthStart, CalendarMonthEnd) VALUES (@CurrentDate, @PublicHoliday, @PublicHolidayName, @Weekend, @NameOfDay, @NameOfMonth, DATEPART(month,@CurrentDate), DATEPART(year,@CurrentDate), DATEPART(week,@CurrentDate), @CalendarMonthStart, @CalendarMonthEnd);
		SET @dayofyear = @dayofyear + 1;
	END;
	SET @inputYear = CAST(CAST(@inputYear as INT) + 1 as NVARCHAR(4));
	SET @YearIncrement = @YearIncrement + 1;
END;
END;
