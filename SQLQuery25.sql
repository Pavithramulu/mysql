USE [_@test]
GO
/****** Object:  StoredProcedure [dbo].[StudentSP]    Script Date: 27-04-2023 04:08:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[StudentSP] 
		@name varchar(50) = NULL,
		@tamil int = 0,
		@english int = 0,
		@maths int = 0,
		@science int = 0,
		@social int = 0,
		@Action varchar(50) = NULL,@studentId int = 0

AS
BEGIN

	SET NOCOUNT ON;

    IF(@Action = 'Insert')
	BEGIN

		INSERT INTO [dbo].[Sscore]
           ([Student_ID],
            [Name],
            [Tamil],
            [English],
            [Maths],
            [Science],
            [SScience])
     VALUES (@studentId,@name,@tamil,@english,@maths,@science,@social)

	END

	ELSE IF(@Action = 'GetStudentDetails')
	BEGIN

		Select * from Sscore

	END
		ELSE IF(@Action = 'GetStudentDetailsById')
	BEGIN

		Select * from Sscore where Student_ID = @studentId

	END

END
