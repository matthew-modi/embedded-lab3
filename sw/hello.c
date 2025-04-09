/*
 * Userspace program that communicates with the vga_ball device driver
 * through ioctls
 *
 * Stephen A. Edwards
 * Columbia University
 */

#include <stdio.h>
#include "vga_ball.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int vga_ball_fd;

/* Read and print the background color */
void print_background_color()
{
    vga_ball_arg_t vla;

    if (ioctl(vga_ball_fd, VGA_BALL_READ_BACKGROUND, &vla))
    {
        perror("ioctl(VGA_BALL_READ_BACKGROUND) failed");
        return;
    }
    printf("%02x %02x %02x\n",
           vla.background.red, vla.background.green, vla.background.blue);
}

/* Set the background color */
void set_background_color(const vga_ball_color_t *c)
{
    vga_ball_arg_t vla;
    vla.background = *c;
    if (ioctl(vga_ball_fd, VGA_BALL_WRITE_BACKGROUND, &vla))
    {
        perror("ioctl(VGA_BALL_SET_BACKGROUND) failed");
        return;
    }
}

void print_position()
{
    vga_ball_arg_t vla;
    if (ioctl(vga_ball_fd, VGA_BALL_READ_POSITION, &vla))
    {
        perror("ioctl(VGA_BALL_READ_POSITION) failed");
        return;
    }
    printf("x: %04x, y: %04x\n",
           vla.position.x, vla.position.y);
}

void set_position(const vga_ball_position_t *position)
{
    vga_ball_arg_t vla;
    vla.position = *position;
    if (ioctl(vga_ball_fd, VGA_BALL_WRITE_POSITION, &vla))
    {
        perror("ioctl(VGA_BALL_SET_POSITION) failed");
        return;
    }
}

/* Convert HSV to RGB color space
 * h: hue (0-360 degrees)
 * s: saturation (0-1)
 * v: value (0-1)
 * r, g, b: output RGB values (0-255)
 */
void hsv_to_rgb(float h, float s, float v, int *r, int *g, int *b)
{
    while (h >= 360)
        h -= 360;
    while (h < 0)
        h += 360;

    int i = h / 60;
    float f = (h / 60) - i;
    float p = v * (1 - s);
    float q = v * (1 - s * f);
    float t = v * (1 - s * (1 - f));

    float r1, g1, b1;
    switch (i)
    {
    case 0:
        r1 = v;
        g1 = t;
        b1 = p;
        break;
    case 1:
        r1 = q;
        g1 = v;
        b1 = p;
        break;
    case 2:
        r1 = p;
        g1 = v;
        b1 = t;
        break;
    case 3:
        r1 = p;
        g1 = q;
        b1 = v;
        break;
    case 4:
        r1 = t;
        g1 = p;
        b1 = v;
        break;
    default:
        r1 = v;
        g1 = p;
        b1 = q;
        break;
    }

    *r = (int)(r1 * 255);
    *g = (int)(g1 * 255);
    *b = (int)(b1 * 255);
}

int main()
{
    vga_ball_arg_t vla;
    int i;
    static const char filename[] = "/dev/vga_ball";

    printf("VGA ball Userspace program started\n");

    if ((vga_ball_fd = open(filename, O_RDWR)) == -1)
    {
        fprintf(stderr, "could not open %s\n", filename);
        return -1;
    }

    int r, g, b;
    float h = 0.0, s = 1.0, v = 1.0;

    float x = 0.2, y; // 16 bit so 0 to 2^16=65536-1
    float dx = 0.01, dy = 0.01; // velocity in x and y directions

    for (;;)
    {
        // Set the background color using HSV to RGB conversion
        hsv_to_rgb(h, s, v, &r, &g, &b);
        h += .5; // Increment hue
        if (h >= 360.0)
            h = 0.0;
        vga_ball_color_t color = {r, g, b};
        set_background_color(&color);
        printf("HSV: h=%.2f s=%.2f v=%.2f -> RGB: r=%d g=%d b=%d\n", h, s, v, r, g, b);
        
        // Bounce the ball around the screen
        x += dx;
        y += dy;
        if (x >= 1.0 || x <= 0.0)
        {
            dx = -dx;
            x += dx;
        }
        if (y >= 1.0 || y <= 0.0)
        {
            dy = -dy;
            y += dy;
        }
        
        vga_ball_position_t position = { // map x and y (0 to 1) to ints from 0 to 65535
            (unsigned short)(x * 170), 
            (unsigned short)(y * 120)};
        set_position(&position);
        print_position();

        usleep(20000);
    }

    printf("VGA BALL Userspace program terminating\n");
    return 0;
}