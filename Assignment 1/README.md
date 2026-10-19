# CS 240 - Computer Organization

## The Repository
This repository ("`CS 240`") is where we (SDSU students) develop the required software applications for the CS 240 - Computer Organization class, together with the community. Not only do we work on code and issues here, but we also publish our Roadmap. This source code is available to everyone under the standard [MIT license](https://github.com/DomTheDeveloper/CS240/blob/main/LICENSE.txt).

## CS 240 - Computer Organization

<p align="center">
  <img alt="Screenshot of CS 240 pixelation code" src="(screenshot of code will go here)">
</p>

This CS 240 repository contains a variety of assignments from the CS 240 class, including a ASCII-to-Decimal Converter, Bitmap-to-Text-File Converter, Text-File-To-Bitmap-Converter, and a Base Number Converter.

### ASCII-to-Decimal Converter
This ASCII to Decimal Converter allows the user to input a string (for example, their name), and returns a line-delimited integer list of the ASCII Decimal values of each character in the input string.

```
s = "Carter"

for c in s:
      print(ord(c))
```

### Number Base Converter
This Number Base Converter allows the user to input a number in base 2, 8, 10, or 16 and a target base (2, 8, 10, or 16) to convert to, this returns the converted number in the specified target base. 

```
import java.util.Scanner;

public class NumberBaseConverter {
    // Build a number-base converter supporting binary, decimal, octal, and hexadecimal.
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);

        System.out.print("Enter a number: ");
        String input = in.nextLine();
        System.out.print("Enter number base to convert FROM (2, 8, 10, or 16): ");
        int inBase = in.nextInt();
        System.out.print("Enter number base to convert TO (2, 8, 10, or 16): ");
        int outBase = in.nextInt();

        
        // input value is converted to decimal
        String decimalInput = inputToDecimal(input, inBase);
        // System.out.println("Decimal number: " + decimalInput);

        // decimal value passed to convertNumber() to convert to specified base
        String convertOutput = convertNumber(decimalInput, outBase);
        // System.out.println("Converted number: " + convertOutput);
        
        
        if (convertOutput.equals("invalid num") || decimalInput.equals("invalid num")) {
            System.out.println("Number too large or invalid number/base.");
        } else {
            System.out.println("The base " + inBase + " number \"" + input + "\" in base " + outBase + " is: " + convertOutput);
        }

    }

    // Convert the input number to decimal
    public static String inputToDecimal(String input, int inBase) {
       try { 
            switch (inBase) {
                case 2:
                    return Integer.toString(Integer.parseInt(input, 2));
                case 8:
                    return Integer.toString(Integer.parseInt(input, 8));
                case 10:
                    return input;
                case 16:
                    return Integer.toString(Integer.parseInt(input.toUpperCase(), 16));
                default:
                    return "invalid num";
            }
        } catch (NumberFormatException e) {
            return "invalid num";
        }
    }

    // Convert the input number to the specified base
    public static String convertNumber(String input, int outBase){
        try {    
            switch (outBase) {
                case 2:
                    return Integer.toBinaryString(Integer.parseInt(input));
                case 8:
                    return Integer.toOctalString(Integer.parseInt(input));
                case 10:
                    return Integer.toString(Integer.parseInt(input));
                case 16:
                    return Integer.toHexString(Integer.parseInt(input)).toUpperCase();
                default:
                    return "invalid num";
                }
        } catch (NumberFormatException e) {
            return "invalid num";
        }
    }
}
```

### Bitmap-to-Text-File Converter
This Bitmap-to-Text-File Converter allows the user to input an image file and returns a text file with the RGB values of each pixel, columns delimited by spaces, rows delimited by lines.

```
from PIL import Image

image = Image.open("./image.png").convert("RGBA")
output_text_file = open("imageAsRGB.txt", "w")

# x, y = 0, 0

for y in range(image.height):
   for x in range(image.width):
      r, g, b, _ = image.getpixel((x,y))
      pixel = f"({r},{g},{b})"
      # pixel = convert(pixel)

      output_text_file.write(pixel)
      output_text_file.write(" ")
   output_text_file.write("\n")

output_text_file.close()
```


### Text-File-To-Bitmap-Converter
This Text-File-To-Bitmap-Converter allows the user to input a text file of space and line delimited RGB values and returns an image of those values.

```
from PIL import Image

def convert(code):
   if code.startswith("("):
      r, g, b = code.strip("()").split(",")
      return (int(r), int(g), int(b))


input_text_file = open("imageAsRGB.txt", "r")
lines = input_text_file.readlines()
h, w = len(lines), lines[0].count(" ")
img = Image.new(mode = "RGB", size = (w,h), color = (0,0,0))

# print(h)
# print(w)

for y in range(h):
   pixels = lines[y].split()
   # print(pixels)
   for x in range(w):
      pixel = pixels[x]
      img.putpixel((x, y), convert(pixel))


img.save("image2.png")

input_text_file.close()
```


## Contributing
Students are welcome to contribute to this repository.

## Feedback

TODO

## Related Projects

TODO

## Code of Conduct

TODO

## License

Licensed under the [MIT](LICENSE.txt) license.

Visual Studio Code is updated monthly with new features and bug fixes. You can download it for Windows, macOS, and Linux on the [Visual Studio Code website](https://code.visualstudio.com/Download). To get the latest releases every day, install the [Insiders build](https://code.visualstudio.com/insiders).
