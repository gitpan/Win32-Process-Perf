// PerfMon.xs
//       +==========================================================+
//       |                                                          |
//       |                        PerfMon.xs                        |
//       |                     ---------------                      |
//       |                                                          |
//       | Copyright (c) 2004 Glen Small. All rights reserved. 	    |
//       |   This program is free software; you can redistribute    |
//       | it and/or modify it under the same terms as Perl itself. |
//       |                                                          |
//       +==========================================================+
//
//
//	Use under GNU General Public License or Larry Wall's "Artistic License"
//
//Check the README.TXT file that comes with this package for details about
//	it's history.
//

#define WIN32_LEAN_AND_MEAN

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "windows.h"
#include "PDH.h"
#include "PDHMSG.h"
#include "perf.h"

MODULE = Win32::Process::Perf		PACKAGE = Win32::Process::Perf

void
open_query()

	PREINIT:

		PDH_STATUS stat;
		HQUERY	hQwy;

	PPCODE:

		stat = PdhOpenQuery(NULL, 0, &hQwy);


		if(stat != ERROR_SUCCESS)
		{
			XPUSHs(sv_2mortal(newSViv(-1)));
		}
		else
		{
			XPUSHs(sv_2mortal(newSViv((long)hQwy)));
		}




void
CleanUp(objQuery)
	SV* objQuery

	PREINIT:

		PDH_STATUS stat;
		HQUERY	pObj;

	PPCODE:

		pObj = (HQUERY)SvIV(objQuery);

		stat = PdhCloseQuery(pObj);


void
add_counter(PName, ObjectName, CounterName, pQwy, pError)
	SV* PName
	SV* ObjectName
	SV* CounterName
	SV* pQwy
	SV* pError

	PREINIT:

		DWORD dwSize;
		DWORD dwGlen;
		HCOUNTER cnt;
		HQUERY hQwy;
		char str[512];
		PDH_STATUS	stat;
		STRLEN len1;
		STRLEN len2;
		STRLEN len3;

	PPCODE:

		hQwy = (HQUERY)SvIV(pQwy);

		dwGlen = 0;
		dwSize = 256;

		len1 = sv_len(ObjectName);
		len2 = sv_len(CounterName);
		len3 = sv_len(PName);
		if(!SvPOK(ObjectName))
		{
			croak("No process given");
		}
		if(!SvPOK(CounterName))
		{
			croak("No counter given");
		}
		
		sprintf(str,"\\%s(%s)\\%s",SvPV(PName,len3), SvPV(ObjectName,len1),SvPV(CounterName,len2));
		stat = PdhAddCounter(hQwy, (LPTSTR)str, dwGlen, &cnt);
			switch(stat)
			{
				case ERROR_SUCCESS:

					XPUSHs(sv_2mortal(newSViv((long)cnt)));
					break;

				case PDH_CSTATUS_BAD_COUNTERNAME:

					sv_setpv(pError, "The counter name path string could not be parsed or interpreted.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_COUNTER:

					sv_setpv(pError, "The specified counter was not found.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_COUNTERNAME:

					sv_setpv(pError, "An empty counter name path string was passed in.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_MACHINE:

					sv_setpv(pError, "A computer entry could not be created.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_OBJECT:

					sv_setpv(pError, "The specified object could not be found.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_FUNCTION_NOT_FOUND:

					sv_setpv(pError, "The calculation function for this counter could not be determined.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_INVALID_ARGUMENT:

					sv_setpv(pError, "One or more arguments are invalid.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_INVALID_HANDLE:

					sv_setpv(pError, "The query handle is not valid.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_MEMORY_ALLOCATION_FAILURE:

					sv_setpv(pError, "A memory buffer could not be allocated.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				default:

					sv_setpv(pError, "Failed to add the counter - don't know why");
					XPUSHs(sv_2mortal(newSViv(-1)));
		}
		





void
collect_data(pQwy, pError)
	SV* pQwy
	SV* pError

	PREINIT:

		HQUERY hQwy;
		PDH_STATUS stat;

	PPCODE:


		hQwy = (HQUERY)SvIV(pQwy);

		stat = PdhCollectQueryData(hQwy);

		switch(stat)
		{
			case ERROR_SUCCESS:

				XPUSHs(sv_2mortal(newSViv(0)));
				break;

			case PDH_INVALID_HANDLE:

				sv_setpv(pError, "The query handle is not valid.");
				XPUSHs(sv_2mortal(newSViv(-1)));
				break;

			case PDH_NO_DATA:

				sv_setpv(pError, "The query does not currently have any counters.");
				XPUSHs(sv_2mortal(newSViv(-1)));
				break;

			default:

				sv_setpv(pError, "Collect Data Failed - I don't know why");
				XPUSHs(sv_2mortal(newSViv(-1)));
				break;

		}

void
collect_counter_value(pQwy, pCounter, pError)
	SV* pQwy
	SV* pCounter
	SV* pError

	PREINIT:

		HQUERY hQwy;
		HCOUNTER hCnt;
		PDH_STATUS stat;
		PDH_FMT_COUNTERVALUE val;
		DWORD dwType;

	PPCODE:

		hQwy = (HQUERY)SvIV(pQwy);
		hCnt = (HCOUNTER)SvIV(pCounter);

		stat = PdhGetFormattedCounterValue(hCnt, PDH_FMT_LONG | PDH_FMT_NOSCALE , &dwType, &val);

		switch(stat)
		{
			case ERROR_SUCCESS:

				XPUSHs(sv_2mortal(newSViv(val.longValue)));

				break;

			case PDH_INVALID_ARGUMENT:

				sv_setpv(pError, "An argument is not correct or is incorrectly formatted.");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			case PDH_INVALID_DATA:

				sv_setpv(pError, "The specified counter does not contain valid data or a successful status code.");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			case PDH_INVALID_HANDLE:

				sv_setpv(pError, "The counter handle is not valid.");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			default:

				sv_setpv(pError, "Failed to get the counter value - I don't know why.");
				XPUSHs(sv_2mortal(newSViv(-1)));

		}


void
list_objects(pBox, pError)
	SV*	pBox
	SV* pError

	PREINIT:

		DWORD dwSize;
		PDH_STATUS stat;
		char* szBuffer;
		char* szBox;
		STRLEN len;

	PPCODE:

		len = sv_len(pBox);
		szBox = SvPV(pBox, len);

		stat = PdhEnumObjects(NULL, szBox, NULL, &dwSize, PERF_DETAIL_NOVICE, 0);

		Newz(0, szBuffer, (int)dwSize, char);

		stat = PdhEnumObjects(NULL, szBox, szBuffer, &dwSize, PERF_DETAIL_NOVICE, 0);

		switch(stat)
		{
			case ERROR_SUCCESS:

				XPUSHs(sv_2mortal(newSVpv(szBuffer, 0)));

				break;

			case PDH_MORE_DATA:

				printf("There are more entries available to return than there is room in the buffer\n");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			case PDH_INSUFFICIENT_BUFFER:

				sv_setpv(pError, "The buffer provided is not large enough to contain any data.\n");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			case PDH_INVALID_ARGUMENT:

				sv_setpv(pError, "A required argument is invalid or a reserved argument is not NULL.\n");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			default:

				sv_setpv(pError, "I have no idea what went wrong\n");
				XPUSHs(sv_2mortal(newSViv(-1)));
		}

		Safefree(szBuffer);

void
connect_to_box(pBox, pError)
	SV* pBox
	SV* pError

	PREINIT:

		PDH_STATUS stat;
		char* szBox;
		STRLEN len;

	PPCODE:

		len = sv_len(pBox);
		szBox = SvPV(pBox, len);

		stat = PdhConnectMachine(szBox);

		switch(stat)
		{
			case ERROR_SUCCESS:

				XPUSHs(sv_2mortal(newSViv(0)));

				break;

			case PDH_CSTATUS_NO_MACHINE:

				sv_setpv(pError, "Unable to connect to the specified machine");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			case PDH_MEMORY_ALLOCATION_FAILURE:

				sv_setpv(pError, "Unable to allocate a dynamic memory block due to too many applications running on the system or an insufficient memory paging file.");
				XPUSHs(sv_2mortal(newSViv(-1)));

				break;

			default:

				sv_setpv(pError, "ERROR: Don't really know what happened though !");
				XPUSHs(sv_2mortal(newSViv(-1)));
		}

void explain_counter(pObject, pCounter, pInstance, pQwy, pError)
	SV* pObject
	SV* pCounter
	SV* pInstance
	SV* pQwy
	SV* pError

	PREINIT:

		PDH_COUNTER_PATH_ELEMENTS	GStruct;
		PDH_COUNTER_INFO* cntInfo;
		DWORD dwSize;
		DWORD dwSize1;
		DWORD dwGlen;
		HCOUNTER cnt;
		HQUERY hQwy;
		char str[256];
		PDH_STATUS	stat;
		STRLEN len1;
		STRLEN len2;
		STRLEN len3;

	PPCODE:

		hQwy = (HQUERY)SvIV(pQwy);

		dwGlen = 1;
		dwSize = 256;
		cntInfo = NULL;

		len1 = sv_len(pObject);
		len2 = sv_len(pCounter);

		if(SvNIOK(pInstance))
		{
			GStruct.szInstanceName = NULL;
		}
		else
		{
			len3 = sv_len(pInstance);
			GStruct.szInstanceName = SvPV(pInstance, len3);
		}

		GStruct.szObjectName = SvPV(pObject, len1);
		GStruct.szCounterName = SvPV(pCounter, len2);
		GStruct.szMachineName = NULL;
		GStruct.szParentInstance = NULL;
		GStruct.dwInstanceIndex = 0;

		stat = PdhMakeCounterPath(&GStruct, (char*)str, &dwSize, NULL);

		if(stat != ERROR_SUCCESS)
		{
			sv_setpv(pError, "Path to that counter isn't valid");
			XPUSHs(sv_2mortal(newSViv(-1)));
		}
		else
		{
			switch(stat)
			{
				case ERROR_SUCCESS:

					stat = PdhGetCounterInfo(&cnt, 1, &dwSize1, cntInfo);

					New(0, cntInfo, (int)dwSize1, PDH_COUNTER_INFO);

					stat = PdhGetCounterInfo(&cnt, 1, &dwSize1, cntInfo);

					if(stat ==  ERROR_SUCCESS)
					{
						XPUSHs(sv_2mortal(newSVpv(cntInfo->szExplainText, 0)));

						Safefree(cntInfo);
					}
					else
					{
						sv_setpv(pError, "Failed to get the explain text for this counter");
						XPUSHs(sv_2mortal(newSViv(-1)));
					}

					break;

				case PDH_CSTATUS_BAD_COUNTERNAME:

					sv_setpv(pError, "The counter name path string could not be parsed or interpreted.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_COUNTER:

					sv_setpv(pError, "The specified counter was not found.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_COUNTERNAME:

					sv_setpv(pError, "An empty counter name path string was passed in.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_MACHINE:

					sv_setpv(pError, "A computer entry could not be created.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_CSTATUS_NO_OBJECT:

					sv_setpv(pError, "The specified object could not be found.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_FUNCTION_NOT_FOUND:

					sv_setpv(pError, "The calculation function for this counter could not be determined.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_INVALID_ARGUMENT:

					sv_setpv(pError, "One or more arguments are invalid.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_INVALID_HANDLE:

					sv_setpv(pError, "The query handle is not valid.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				case PDH_MEMORY_ALLOCATION_FAILURE:

					sv_setpv(pError, "A memory buffer could not be allocated.");
					XPUSHs(sv_2mortal(newSViv(-1)));

					break;

				default:

					sv_setpv(pError, "Failed to add the counter - don't know why");
					XPUSHs(sv_2mortal(newSViv(-1)));
			}
		}


	