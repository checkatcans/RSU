from monai.data import load_decathlon_datalist, DataLoader, Dataset
from monai.transforms import (
    LoadImaged, EnsureChannelFirstd, Orientationd, Spacingd,
    ScaleIntensityRanged, CropForegroundd, RandFlipd, RandCropByPosNegLabeld,
    RandRotate90d, EnsureTyped
)
import json

# Path to your dataset.json
data_dir = "/home/k8suser/data/Task04_Hippocampus"
json_path = f"{data_dir}/dataset.json"

# Load datalist
with open(json_path) as f:
    datalist = json.load(f)

train_files = datalist["training"]
val_files = datalist.get("validation", train_files[:10])  # if validation not defined

# Transforms
train_transforms = [
    LoadImaged(keys=["image", "label"]),
    EnsureChannelFirstd(keys=["image", "label"]),
    Orientationd(keys=["image", "label"], axcodes="RAS"),
    Spacingd(keys=["image", "label"], pixdim=(1.0, 1.0, 1.0)),
    ScaleIntensityRanged(keys=["image"], a_min=-1000, a_max=1000,
                        b_min=0.0, b_max=1.0, clip=True),
    CropForegroundd(keys=["image", "label"], source_key="image"),
    RandCropByPosNegLabeld(
        keys=["image", "label"],
        label_key="label",
        spatial_size=(96, 96, 96),
        pos=1,
        neg=1,
        num_samples=4,
    ),
    RandRotate90d(keys=["image", "label"], prob=0.5),
    EnsureTyped(keys=["image", "label"]),
]

train_ds = Dataset(data=train_files, transform=train_transforms)
train_loader = DataLoader(train_ds, batch_size=2, shuffle=True, num_workers=4)
