-----------------------------------------------------------------------
--  util-dates-formats-tests - Test for date formats
--  Copyright (C) 2011, 2013, 2014, 2016, 2017 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------

with Ada.Calendar.Formatting;
with Util.Test_Caller;
with Util.Assertions;
with Util.Properties.Bundles;
with Util.Log.Loggers;
with Util.Dates.RFC7231;
with Util.Dates.ISO8601;
package body Util.Dates.Formats.Tests is

   use Util.Tests;
   use Ada.Strings.Unbounded;

   --  The logger
   Log : constant Util.Log.Loggers.Logger := Util.Log.Loggers.Create ("Util.Dates.Formats.Tests");

   package Caller is new Util.Test_Caller (Test, "Dates");
   procedure Check (T    : in out Test;
                    Date : in String);
   procedure Check (T          : in out Test'Class;
                    Year       : in Ada.Calendar.Year_Number;
                    Month      : in Ada.Calendar.Month_Number;
                    Day        : in Ada.Calendar.Day_Number;
                    Expect_Day : in Ada.Calendar.Day_Number;
                    Message    : in String;
                    Is_End     : in Boolean;
                    Operation  : access function (D : in Ada.Calendar.Time)
                    return Ada.Calendar.Time);

   procedure Add_Tests (Suite : in Util.Tests.Access_Test_Suite) is
   begin
      Caller.Add_Test (Suite, "Test Util.Dates.Split",
                       Test_Split'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Formats.Format",
                       Test_Format'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Get_Day_Start",
                       Test_Get_Day_Start'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Get_Week_Start",
                       Test_Get_Week_Start'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Get_Month_Start",
                       Test_Get_Month_Start'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Get_Day_End",
                       Test_Get_Day_End'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Get_Week_End",
                       Test_Get_Week_End'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.Get_Month_End",
                       Test_Get_Month_End'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.RFC7231.Append_Date",
                       Test_Append_Date'Access);
      Caller.Add_Test (Suite, "Test Util.Dates.ISO8601.Image",
                       Test_ISO8601'Access);
   end Add_Tests;

   procedure Test_Format (T : in out Test) is
      Bundle  : Util.Properties.Bundles.Manager;
      procedure Check (Pattern : in String;
                       Date    : in Ada.Calendar.Time;
                       Expect  : in String);

      procedure Check (Pattern : in String;
                       Date    : in Ada.Calendar.Time;
                       Expect  : in String) is
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Util.Dates.Formats.Format (Pattern => Pattern,
                                    Date    => Date,
                                    Bundle  => Bundle,
                                    Into    => Result);
         Util.Tests.Assert_Equals (T, Expect, To_String (Result),
                                   "Invalid result for: " & Pattern);
      end Check;

      T1 : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (1980, 1, 2, 10, 30, 23);
      T2 : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (2011, 11, 19, 0, 0, 0);
      T3 : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (2011, 11, 19, 23, 0, 0);
   begin
      Check ("%H", T1, "10");
      Check ("%H", T2, "00");
      Check ("%I", T3, "11");
      Check ("%k", T2, " 0");
      Check ("%k", T3, "23");
      Check ("%l", T2, " 0");
      Check ("%l", T3, "11");

      Check ("%r", T3, "11:00:00 PM");
      Check ("%r", T2, "00:00:00 AM");
      Check ("%R:%S", T3, "23:00:00");

      Check ("%y-%Y %m/%d %T", T1, "80-1980 01/02 10:30:23");
      Check ("%C %d %D", T1, "19 02 01/02/80");
      Check ("%e", T1, " 1");
      Check ("%F", T1, "1980-01-02");
      Check ("%G", T1, "1980W01");
      Check ("%g", T1, "80W01");

   end Test_Format;

   procedure Check (T          : in out Test'Class;
                    Year       : in Ada.Calendar.Year_Number;
                    Month      : in Ada.Calendar.Month_Number;
                    Day        : in Ada.Calendar.Day_Number;
                    Expect_Day : in Ada.Calendar.Day_Number;
                    Message    : in String;
                    Is_End     : in Boolean;
                    Operation  : access function (D : in Ada.Calendar.Time)
                    return Ada.Calendar.Time) is
      use type Ada.Calendar.Time;

      Date : Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (Year, Month, Day,
                                                                   0, 0, 0);
   begin
      for I in 1 .. 47 loop
         declare
            R : constant Ada.Calendar.Time := Operation (Date);
            D : Date_Record;
         begin
            Split (D, R);
            Log.Info ("{0} ({1}) => {2}",
                      Ada.Calendar.Formatting.Image (Date),
                      Message, Ada.Calendar.Formatting.Image (R));
            Util.Tests.Assert_Equals (T, Natural (Year), Natural (D.Year),
                                      "Invalid year " & Message);
            Util.Tests.Assert_Equals (T, Natural (Month), Natural (D.Month),
                                      "Invalid month " & Message);
            Util.Tests.Assert_Equals (T, Natural (Expect_Day), Natural (D.Month_Day),
                                      "Invalid day " & Message);
            if Is_End then
               Util.Tests.Assert_Equals (T, 23, Natural (D.Hour),
                                         "Invalid hour " & Message);
               Util.Tests.Assert_Equals (T, 59, Natural (D.Minute),
                                         "Invalid minute " & Message);
               Util.Tests.Assert_Equals (T, 59, Natural (D.Second),
                                         "Invalid second " & Message);
            else
               Util.Tests.Assert_Equals (T, 0, Natural (D.Hour),
                                         "Invalid hour " & Message);
               Util.Tests.Assert_Equals (T, 0, Natural (D.Minute),
                                         "Invalid minute " & Message);
               Util.Tests.Assert_Equals (T, 0, Natural (D.Second),
                                         "Invalid second " & Message);
            end if;
         end;
         Date := Date + 1800.0;
      end loop;
   end Check;

   --  ------------------------------
   --  Test the Get_Day_Start operation.
   --  ------------------------------
   procedure Test_Get_Day_Start (T : in out Test) is
   begin
      Check (T, 2013, 6, 04, 04, "Get_Day_Start", False, Get_Day_Start'Access);
      Check (T, 2010, 2, 14, 14, "Get_Day_Start", False, Get_Day_Start'Access);
   end Test_Get_Day_Start;

   --  ------------------------------
   --  Test the Get_Week_Start operation.
   --  ------------------------------
   procedure Test_Get_Week_Start (T : in out Test) is
   begin
      Check (T, 2013, 6, 04, 03, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2013, 6, 03, 03, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2013, 6, 05, 03, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2013, 6, 08, 03, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2010, 2, 14, 08, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2010, 2, 13, 08, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2010, 2, 10, 08, "Get_Week_Start", False, Get_Week_Start'Access);
      Check (T, 2010, 2, 15, 15, "Get_Week_Start", False, Get_Week_Start'Access);
   end Test_Get_Week_Start;

   --  ------------------------------
   --  Test the Get_Month_Start operation.
   --  ------------------------------
   procedure Test_Get_Month_Start (T : in out Test) is
   begin
      Check (T, 2013, 6, 04, 01, "Get_Month_Start", False, Get_Month_Start'Access);
      Check (T, 2010, 2, 14, 01, "Get_Month_Start", False, Get_Month_Start'Access);
   end Test_Get_Month_Start;

   --  ------------------------------
   --  Test the Get_Day_End operation.
   --  ------------------------------
   procedure Test_Get_Day_End (T : in out Test) is
   begin
      Check (T, 2013, 6, 04, 04, "Get_Day_Start", True, Get_Day_End'Access);
      Check (T, 2010, 2, 14, 14, "Get_Day_Start", True, Get_Day_End'Access);
   end Test_Get_Day_End;

   --  ------------------------------
   --  Test the Get_Week_End operation.
   --  ------------------------------
   procedure Test_Get_Week_End (T : in out Test) is
   begin
      Check (T, 2013, 6, 04, 09, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2013, 6, 03, 09, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2013, 6, 05, 09, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2013, 6, 08, 09, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2010, 2, 14, 14, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2010, 2, 13, 14, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2010, 2, 10, 14, "Get_Week_End", True, Get_Week_End'Access);
      Check (T, 2010, 2, 15, 21, "Get_Week_End", True, Get_Week_End'Access);
   end Test_Get_Week_End;

   --  ------------------------------
   --  Test the Get_Month_End operation.
   --  ------------------------------
   procedure Test_Get_Month_End (T : in out Test) is
   begin
      Check (T, 2013, 6, 04, 30, "Get_Month_End", True, Get_Month_End'Access);
      Check (T, 2010, 2, 14, 28, "Get_Month_End", True, Get_Month_End'Access);
      Check (T, 2000, 2, 14, 29, "Get_Month_End", True, Get_Month_End'Access);
   end Test_Get_Month_End;

   --  ------------------------------
   --  Test the Split operation.
   --  ------------------------------
   procedure Test_Split (T : in out Test) is
      procedure Assert_Equals is
         new Util.Assertions.Assert_Equals_T (Ada.Calendar.Formatting.Day_Name);

      Date : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (2014, 11, 12,
                                                                            23, 30, 0);
      D    : Date_Record;
   begin
      Split (D, Date);
      Util.Tests.Assert_Equals (T, 2014, Natural (D.Year), "Invalid year ");
      Util.Tests.Assert_Equals (T, 11, Natural (D.Month), "Invalid month ");
      Util.Tests.Assert_Equals (T, 12, Natural (D.Month_Day), "Invalid day ");
      Util.Tests.Assert_Equals (T, 23, Natural (D.Hour), "Invalid hour ");
      Util.Tests.Assert_Equals (T, 30, Natural (D.Minute), "Invalid minute ");
      Assert_Equals (T, Ada.Calendar.Formatting.Wednesday, D.Day, "Invalid day ");
   end Test_Split;

   procedure Check (T    : in out Test;
                    Date : in String) is
      D : constant Ada.Calendar.Time := Util.Dates.RFC7231.Value (Date);
      F : constant String := Util.Dates.RFC7231.Image (D);
   begin
      Util.Tests.Assert_Equals (T, Date, F, "Invalid date conversion");
   end Check;

   --  ------------------------------
   --  Test the Append_Date as well as the Image operation
   --  ------------------------------
   procedure Test_Append_Date (T : in out Test) is
   begin
      Check (T, "Mon, 26 Mar 2012 19:43:47 GMT");
      Check (T, "Tue, 02 Feb 2016 15:18:35 GMT");
      Check (T, "Wed, 07 Oct 2015 03:41:11 GMT");
      Check (T, "Thu, 17 Sep 2015 10:07:02 GMT");
      Check (T, "Sat, 03 Oct 2015 17:09:58 GMT");
      Check (T, "Fri, 17 Jul 2015 16:07:54 GMT");
      Check (T, "Sun, 04 Oct 2015 15:10:44 GMT");
   end Test_Append_Date;

   --  ------------------------------
   --  Test the ISO8601 operations.
   --  ------------------------------
   procedure Test_ISO8601 (T : in out Test) is
      Date : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (2014, 11, 12,
                                                                            23, 30, 4, 0.123456);
      D    : Date_Record;
   begin
      Split (D, Date);
      Util.Tests.Assert_Equals (T, "2014", ISO8601.Image (D, ISO8601.YEAR));
      Util.Tests.Assert_Equals (T, "2014-11", ISO8601.Image (D, ISO8601.MONTH));
      Util.Tests.Assert_Equals (T, "2014-11-12", ISO8601.Image (D, ISO8601.DAY));
      Util.Tests.Assert_Equals (T, "2014-11-12T23", ISO8601.Image (D, ISO8601.HOUR));
      Util.Tests.Assert_Equals (T, "2014-11-12T23:30", ISO8601.Image (D, ISO8601.MINUTE));
      Util.Tests.Assert_Equals (T, "2014-11-12T23:30:04", ISO8601.Image (D, ISO8601.SECOND));
      Util.Tests.Assert_Equals (T, "2014-11-12T23:30:04.123+00:00",
                                ISO8601.Image (D, ISO8601.SUBSECOND));
   end Test_ISO8601;

end Util.Dates.Formats.Tests;
