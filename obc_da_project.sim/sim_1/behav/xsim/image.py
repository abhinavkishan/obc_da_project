from PIL import Image
import matplotlib.pyplot as plt

# ---- Use your uploaded file paths ----
in_path = "in.pgm"
out_path = "out.pgm"

# Load images
img_in = Image.open(in_path)
img_out = Image.open(out_path)

# Display in subplot
plt.figure(figsize=(10, 5))

plt.subplot(1, 2, 1)
plt.imshow(img_in, cmap='gray')
plt.title("Input Image")
plt.axis('off')

plt.subplot(1, 2, 2)
plt.imshow(img_out, cmap='gray')
plt.title("Output Image")
plt.axis('off')

plt.show()
