cmake_minimum_required(VERSION 3.22)

# Toolchain must be set before project()
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/gcc-arm-none-eabi.cmake)

project(stm32h723-blinky C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# ---- MCU configuration -----------------------------------------------------
# WeAct STM32H723VGT6 core board. Change these two if your variant differs.
set(MCU_FAMILY  STM32H7xx)
set(MCU_LINE    STM32H723xx)
set(CPU_FLAGS   -mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb)

# ---- Paths -----------------------------------------------------------------
set(CUBE_H7 ${CMAKE_CURRENT_SOURCE_DIR}/lib/STM32CubeH7)
set(CMSIS   ${CUBE_H7}/Drivers/CMSIS)
set(HAL_DRV ${CUBE_H7}/Drivers/STM32H7xx_HAL_Driver)

# ---- Sources ---------------------------------------------------------------
set(SOURCES
    src/main.c
    src/stm32h7xx_it.c
    src/system_stm32h7xx.c
    src/startup_stm32h723xx.s
    ${HAL_DRV}/Src/stm32h7xx_hal.c
    ${HAL_DRV}/Src/stm32h7xx_hal_cortex.c
    ${HAL_DRV}/Src/stm32h7xx_hal_gpio.c
    ${HAL_DRV}/Src/stm32h7xx_hal_pwr.c
    ${HAL_DRV}/Src/stm32h7xx_hal_pwr_ex.c
    ${HAL_DRV}/Src/stm32h7xx_hal_rcc.c
    ${HAL_DRV}/Src/stm32h7xx_hal_rcc_ex.c
    ${HAL_DRV}/Src/stm32h7xx_hal_flash.c
    ${HAL_DRV}/Src/stm32h7xx_hal_flash_ex.c
    ${HAL_DRV}/Src/stm32h7xx_hal_dma.c
)

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE
    inc
    ${HAL_DRV}/Inc
    ${HAL_DRV}/Inc/Legacy
    ${CMSIS}/Device/ST/STM32H7xx/Include
    ${CMSIS}/Include
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    USE_HAL_DRIVER
    ${MCU_LINE}
)

target_compile_options(${PROJECT_NAME} PRIVATE
    ${CPU_FLAGS}
    -ffunction-sections
    -fdata-sections
    -Wall
    $<$<CONFIG:Debug>:-Og -g3>
    $<$<CONFIG:Release>:-O2>
)

target_link_options(${PROJECT_NAME} PRIVATE
    ${CPU_FLAGS}
    -T${CMAKE_CURRENT_SOURCE_DIR}/STM32H723xx_FLASH.ld
    -Wl,--gc-sections
    -Wl,-Map=${PROJECT_NAME}.map
    --specs=nano.specs
    --specs=nosys.specs
)

# ---- Post-build: .bin/.hex + size report -----------------------------------
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${PROJECT_NAME}>
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.bin
    COMMAND ${CMAKE_OBJCOPY} -O ihex   $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.hex
    COMMENT "Generating .bin/.hex and size report"
)

# ---- Flash target: USB DFU -------------------------------------------------
# Board must be in DFU mode: hold BOOT0, tap RESET (or it enters DFU
# automatically when flash is empty).
if(WIN32)
    set(DFU_UTIL ${CMAKE_CURRENT_SOURCE_DIR}/tools/dfu-util/dfu-util-0.11-binaries/win64/dfu-util.exe)
else()
    find_program(DFU_UTIL dfu-util REQUIRED)
endif()

add_custom_target(flash
    COMMAND ${CMAKE_COMMAND}
        -DDFU_UTIL=${DFU_UTIL}
        -DBIN=$<TARGET_FILE_DIR:${PROJECT_NAME}>/${PROJECT_NAME}.bin
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/flash_dfu.cmake
    COMMENT "Flashing via USB DFU"
    DEPENDS ${PROJECT_NAME}
)
