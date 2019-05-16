USE ['DATABASE']
GO

/****** Object:  StoredProcedure [dbo].[zendeskIntegration_Get_Company_PrimaryPhone_SP]    Script Date: 31-08-2015 15:27:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		https://github.com/larssb
-- Create date: 150831
-- Description:	This sproc gets a company's primary phone number in order to add this to a user being [created] or [updated] on Zendesk.
-- It is called by the PowerShell determineUserPrimaryPhone().
-- =============================================
CREATE PROCEDURE [dbo].[zendeskIntegration_Get_Company_PrimaryPhone_SP] 
	-- Add the parameters for the stored procedure here
	@guid nvarchar(max) 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT ACCOUNT
	FROM ['DATABASE'].[dbo].[AccountSystemRef_View]
	WHERE [Guid] = @guid
END

GO


