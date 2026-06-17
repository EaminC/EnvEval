# EnvEval - Environment Evaluation Benchmark

🌟 **A Comprehensive Benchmark for Environment Configuration and Code Execution**

EnvEval is a benchmark suite specifically designed to evaluate AI models' performance on environment configuration and code execution tasks.

## 📁 Project Structure

```
EnvEval/
├── README.md           # Project documentation
├── LICENSE            # Open source license
├── website/           # Benchmark website
│   ├── index.html    # Main page
│   ├── styles.css    # Stylesheets
│   └── script.js     # Interactive scripts
├── benchmark/         # New benchmark directory with additional tasks and scripts
└── dataset/           # Dataset and results
    ├── index.json    # Benchmark data index
    └── results/      # Result folders (one per model)
```

## 📊 Benchmark Results

### Baseline Methods

- **Codex**: GPT-4.1 (26.15%), GPT-4.1-mini (22.31%)
- **Claude-Code**: Claude-Opus-4 (30.10%), Claude-Haiku-3.5 (18.21%)

### EnvGym Method (Ours)

- **Claude-Opus-4**: 74.01% 🏆 (Highest Score)
- **GPT-4.1**: 70.07%
- **Gemini-2.5-Pro**: 66.81%
- **GPT-4.1-mini**: 53.41%
- **Claude-Haiku-3.5**: 50.59%
- **DeepSeek-V3**: 49.54%
- **DeepSeek-R1**: 42.25%

## 🚀 Quick Start

### View Website

```bash
# Recommended: Use the development server (supports data loading)
cd website
python start_server.py
# Visit http://localhost:8000/website/

# Alternative: Simple server from project root
python -m http.server 8000
# Visit http://localhost:8000/website/
```

### ✨ Dynamic Data Loading

The website automatically loads results from the `dataset/` folder:

- **Real-time updates**: Add new results by updating dataset files
- **No hardcoding**: All benchmark data loaded dynamically from JSON
- **Interactive**: Click any result row for detailed information

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **🌐 Website**: [Online Demo URL]
- **📦 GitHub**: [GitHub Repository URL]
- **📄 Paper**: [arXiv Link]

---

**EnvEval Team**
