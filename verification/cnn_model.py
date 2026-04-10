import numpy as np
import os
import matplotlib.pyplot as plt
from PIL import Image

def to_signed(val, bits):
    mask = (1 << bits) - 1
    val = val & mask
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

class FPGA_CNN:
    def __init__(self, weights_dir="weights"):
        self.weights_dir = weights_dir
        self.weights = {}
        self.biases = {}
        
    def load_weights(self):
        self.conv1_weights = []
        for i in range(1, 4):
            path = os.path.join(self.weights_dir, f"conv1_weight_{i}.txt")
            if os.path.exists(path):
                w = self._read_hex_file(path, 25)
                self.conv1_weights.append(np.array(w).reshape(5, 5))
            else:
                print(f"Warning: {path} not found. Using random weights.")
                self.conv1_weights.append(np.random.randint(-128, 127, (5, 5)))
                
        path = os.path.join(self.weights_dir, "conv1_bias.txt")
        if os.path.exists(path):
            self.conv1_bias = self._read_hex_file(path, 3)
        else:
            print(f"Warning: {path} not found. Using random bias.")
            self.conv1_bias = np.random.randint(-128, 127, 3)

        self.conv2_weights = []
        for out_ch in range(1, 4):
            for in_ch in range(1, 4):
                path = os.path.join(self.weights_dir, f"conv2_weight_{out_ch}{in_ch}.txt")
                if os.path.exists(path):
                    w = self._read_hex_file(path, 25)
                    self.conv2_weights.append(np.array(w).reshape(5, 5))
                else:
                    print(f"Warning: {path} not found. Using random weights.")
                    self.conv2_weights.append(np.random.randint(-128, 127, (5, 5)))
        
        path = os.path.join(self.weights_dir, "conv2_bias.txt")
        if os.path.exists(path):
            self.conv2_bias = self._read_hex_file(path, 3)
        else:
            print(f"Warning: {path} not found. Using random bias.")
            self.conv2_bias = np.random.randint(-128, 127, 3)

        path = os.path.join(self.weights_dir, "fc_weight.txt")
        if os.path.exists(path):
            self.fc_weights = self._read_hex_file(path, 480)
        else:
            print(f"Warning: {path} not found. Using random weights.")
            self.fc_weights = np.random.randint(-128, 127, 480)
            
        path = os.path.join(self.weights_dir, "fc_bias.txt")
        if os.path.exists(path):
            self.fc_bias = self._read_hex_file(path, 10)
        else:
            print(f"Warning: {path} not found. Using random bias.")
            self.fc_bias = np.random.randint(-128, 127, 10)

    def _read_hex_file(self, path, count):
        data = []
        with open(path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                for p in parts:
                    if p:
                        val = int(p, 16)
                        if val > 127:
                            val -= 256
                        data.append(val)
        return data[:count]

    def conv1_layer(self, img):
        print("Running Conv1 Layer...")
        h, w = img.shape
        out_h, out_w = 24, 24
        
        outputs = []
        
        for k in range(3):
            weight = self.conv1_weights[k]
            bias = self.conv1_bias[k]
            
            bias_val = bias << 8
            
            output_map = np.zeros((out_h, out_w), dtype=int)
            
            for r in range(out_h):
                for c in range(out_w):
                    patch = img[r:r+5, c:c+5]
                    
                    conv_sum = np.sum(patch * weight)
                    
                    total = conv_sum + bias_val
                    
                    res = total >> 8
                    
                    res = to_signed(res, 12)
                    
                    output_map[r, c] = res
            
            outputs.append(output_map)
            
        return outputs

    def pool1_layer(self, feature_maps):
        print("Running Pool1 Layer...")
        outputs = []
        
        for fmap in feature_maps:
            h, w = fmap.shape
            out_h, out_w = 12, 12
            output_map = np.zeros((out_h, out_w), dtype=int)
            
            for r in range(out_h):
                for c in range(out_w):
                    patch = fmap[r*2:r*2+2, c*2:c*2+2]
                    max_val = np.max(patch)
                    output_map[r, c] = max_val
            
            outputs.append(output_map)
            
        return outputs

    def conv2_layer(self, feature_maps):
        print("Running Conv2 Layer...")
        out_h, out_w = 8, 8
        outputs = []
        
        for k in range(3):
            bias = self.conv2_bias[k]
            bias_val = bias << 8
            
            output_map = np.zeros((out_h, out_w), dtype=int)
            
            for r in range(out_h):
                for c in range(out_w):
                    conv_sum = 0
                    
                    for ch in range(3):
                        input_map = feature_maps[ch]
                        weight = self.conv2_weights[k*3 + ch]
                        
                        patch = input_map[r:r+5, c:c+5]
                        conv_sum += np.sum(patch * weight)
                    
                    res = conv_sum >> 7
                    
                    res = res + bias
                    
                    res = to_signed(res, 12)
                    
                    output_map[r, c] = res
            
            outputs.append(output_map)
            
        return outputs

    def pool2_layer(self, feature_maps):
        print("Running Pool2 Layer...")
        outputs = []
        
        for fmap in feature_maps:
            h, w = fmap.shape
            out_h, out_w = 4, 4
            output_map = np.zeros((out_h, out_w), dtype=int)
            
            for r in range(out_h):
                for c in range(out_w):
                    patch = fmap[r*2:r*2+2, c*2:c*2+2]
                    max_val = np.max(patch)
                    output_map[r, c] = max_val
            
            outputs.append(output_map)
            
        return outputs

    def full_layer(self, feature_maps):
        print("Running Full Layer...")
        
        flat_input = []
        for fmap in feature_maps:
            flat_input.extend(fmap.flatten())
        
        flat_input = np.array(flat_input)
        
        scores = []
        
        for k in range(10):
            class_weights = self.fc_weights[k*48 : (k+1)*48]
            bias = self.fc_bias[k]
            
            dot_prod = np.sum(flat_input * class_weights)
            
            total = dot_prod + bias
            
            res = total >> 7
            
            res = to_signed(res, 12)
            
            scores.append(res)
            
        return scores

if __name__ == "__main__":
    # Select test image (0-9)
    while True:
        try:
            digit = input("Input the digit to test (0-9): ")
            digit = int(digit)
            if 0 <= digit <= 9:
                break
            else:
                print("Input a valid digit")
        except ValueError:
            print("Input a valid digit")
    
    # Load input image
    img_path = f"{digit}.png"
    if os.path.exists(img_path):
        print(f"Loading {img_path}...")
        img = Image.open(img_path).convert('L')
        img = img.resize((28, 28))
        input_img = np.array(img)
    else:
        print(f"Warning: {img_path} not found. Generating random input and saving as {img_path}.")
        input_img = np.random.randint(0, 256, (28, 28), dtype=np.uint8)
        Image.fromarray(input_img).save(img_path)
    
    cnn = FPGA_CNN(weights_dir="weights")
    cnn.load_weights()
    
    # Run Conv1
    conv1_out = cnn.conv1_layer(input_img)
    print(f"Conv1 Output Shape: {len(conv1_out)} x {conv1_out[0].shape}")
    print("Conv1 Output (Channel 0, Top-Left 5x5):")
    print(conv1_out[0][:5, :5])
    # Save Conv1 outputs
    for i, fmap in enumerate(conv1_out):
        np.savetxt(f"conv1_out_{i}.txt", fmap, fmt="%d")
        plt.imsave(f"conv1_out_{i}.png", fmap, cmap='gray')
    
    # Run Pool1
    pool1_out = cnn.pool1_layer(conv1_out)
    print(f"Pool1 Output Shape: {len(pool1_out)} x {pool1_out[0].shape}")
    print("Pool1 Output (Channel 0, Top-Left 5x5):")
    print(pool1_out[0][:5, :5])
    # Save Pool1 outputs
    for i, fmap in enumerate(pool1_out):
        np.savetxt(f"pool1_out_{i}.txt", fmap, fmt="%d")
        plt.imsave(f"pool1_out_{i}.png", fmap, cmap='gray')
    
    # Run Conv2
    conv2_out = cnn.conv2_layer(pool1_out)
    print(f"Conv2 Output Shape: {len(conv2_out)} x {conv2_out[0].shape}")
    print("Conv2 Output (Channel 0, Top-Left 5x5):")
    print(conv2_out[0][:5, :5])
    # Save Conv2 outputs
    for i, fmap in enumerate(conv2_out):
        np.savetxt(f"conv2_out_{i}.txt", fmap, fmt="%d")
        plt.imsave(f"conv2_out_{i}.png", fmap, cmap='gray')
    
    # Run Pool2
    pool2_out = cnn.pool2_layer(conv2_out)
    print(f"Pool2 Output Shape: {len(pool2_out)} x {pool2_out[0].shape}")
    print("Pool2 Output (Channel 0, Top-Left 4x4):")
    print(pool2_out[0])
    # Save Pool2 outputs
    for i, fmap in enumerate(pool2_out):
        np.savetxt(f"pool2_out_{i}.txt", fmap, fmt="%d")
        plt.imsave(f"pool2_out_{i}.png", fmap, cmap='gray')
    
    # Run Full Layer
    scores = cnn.full_layer(pool2_out)
    print("Full Layer Scores:")
    print(scores)
    np.savetxt("full_layer_scores.txt", scores, fmt="%d")
    
    predicted_digit = np.argmax(scores)
    print(f"Predicted Digit: {predicted_digit}")