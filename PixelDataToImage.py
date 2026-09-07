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