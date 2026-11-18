# DFU flash wrapper.
# The STM32 system bootloader detaches immediately when it processes the
# DFU "leave" request, so dfu-util's final get_status poll fails and it
# exits non-zero even though the download succeeded. Treat the run as
# successful only when the download actually completed.
execute_process(
    COMMAND "${DFU_UTIL}" -d 0483:df11 -a 0 -s 0x08000000:leave -D "${BIN}"
    RESULT_VARIABLE dfu_result
    OUTPUT_VARIABLE dfu_out
    ERROR_VARIABLE dfu_err
)

set(dfu_log "${dfu_out}${dfu_err}")
message(STATUS "${dfu_log}")

if(NOT dfu_log MATCHES "File downloaded successfully")
    message(FATAL_ERROR "DFU download failed (dfu-util exit code ${dfu_result}). Is the board in DFU mode? (Hold BOOT0, tap RESET)")
endif()

message(STATUS "Flash OK - device left DFU mode and started the application.")
