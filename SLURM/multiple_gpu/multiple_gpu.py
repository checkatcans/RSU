import torch
import torch.nn as nn

# Simple model
model = nn.Linear(10, 1)

# Run on multiple GPUs automatically if available
if torch.cuda.device_count() > 1:
    print("Using", torch.cuda.device_count(), "GPUs with DataParallel")
    model = nn.DataParallel(model)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)

# Fake data
x = torch.randn(64, 10).to(device)
y = model(x)
print("Output:", y)
