/**
 * Blinky for WeAct STM32H723VGT6 core board.
 *
 * Runs from the default HSI 64 MHz clock after reset - no PLL/VOS setup
 * needed, which keeps this first bring-up firmware as robust as possible.
 * Add a full clock tree later via STM32CubeMX.
 *
 * LED: PG7 on FK723M1-ZGT6.
 * Toggle both states at 500 ms so it is easy to verify the board pin.
 */
#include "stm32h7xx_hal.h"

#define LED_GPIO_PORT   GPIOG
#define LED_PIN         GPIO_PIN_7
#define LED_GPIO_CLK_EN __HAL_RCC_GPIOG_CLK_ENABLE

void SysTick_Handler(void)
{
    HAL_IncTick();
}

static void LED_Init(void)
{
    LED_GPIO_CLK_EN();

    GPIO_InitTypeDef gpio = {0};
    gpio.Pin   = LED_PIN;
    gpio.Mode  = GPIO_MODE_OUTPUT_PP;
    gpio.Pull  = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(LED_GPIO_PORT, &gpio);
}

int main(void)
{
    HAL_Init();
    LED_Init();

    while (1)
    {
        HAL_GPIO_TogglePin(LED_GPIO_PORT, LED_PIN);
        HAL_Delay(500);
    }
}

void Error_Handler(void)
{
    __disable_irq();
    while (1)
    {
    }
}
