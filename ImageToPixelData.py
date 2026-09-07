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