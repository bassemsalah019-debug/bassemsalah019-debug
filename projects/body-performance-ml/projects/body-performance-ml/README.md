# 🏋️ Body Performance ML Analytics

**Course Project — Introduction to AI & ML | March 2026**
**Team:** Hossam Elnagar · Khaled Metwalie · Hazem Mohamed · Hazem Shokr · **Bassem Salah (Regression Lead)**

---

## 📋 Overview

End-to-end ML pipeline classifying physical fitness into 4 classes (A/B/C/D) from 13,393 records, plus a regression task predicting broad jump distance (cm).

## 🏆 Results

| Task | Best Model | Score |
|------|-----------|-------|
| Classification | Neural Network (128,64) + tanh | Acc=75.29%, AUC=0.9193 |
| Regression (Basic) | SVR-RBF | R²=0.7817, RMSE=18.62cm |
| Regression (Advanced) | Linear + All Enhanced (39f) | R²=0.7841, RMSE=18.52cm |

## 📁 Files

| File | Description |
|------|-------------|
| `BEST_ONE_Enhanced.ipynb` | Full ML pipeline notebook |
| `Prediction_App_Updated.ipynb` | Gradio deployment notebook |
| `Body_Performance_Presentation.pptx` | Project slides |
| `Body_Performance_StoryReport.pdf` | Full storytelling report |
| `bodyPerformance.csv` | Dataset |

## 🛠 Technologies
Python · Scikit-learn · SHAP · Gradio · HuggingFace · Pandas · NumPy · Matplotlib · Seaborn
