#!/usr/bin/env python3
"""
Generate Statistics and Visualizations from Evaluation Reports

Analyzes evaluation reports in reports-by-repo/ and generates comprehensive statistics
and visualizations comparing model performance across repositories and categories.

Usage:
    python generate_stats.py --repos Baleen BurntSushi_ripgrep Fairify
    python generate_stats.py --repos facebook_zstd --output-dir custom-stats
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Any, Tuple
import matplotlib.pyplot as plt
import numpy as np
from collections import defaultdict


def discover_available_repos(reports_dir: str = "reports-by-repo") -> List[str]:
    """
    Discover available repositories with evaluation reports.
    
    Args:
        reports_dir: Directory containing reports organized by repository
        
    Returns:
        List of repository names that have evaluation reports
    """
    reports_path = Path(reports_dir)
    if not reports_path.exists():
        return []
    
    repos = []
    for repo_dir in reports_path.iterdir():
        if repo_dir.is_dir() and (repo_dir / "models").exists():
            # Check if there are any model reports
            models_dir = repo_dir / "models"
            if any(f.suffix == '.json' for f in models_dir.iterdir()):
                repos.append(repo_dir.name)
    
    return sorted(repos)


def load_rubric_categories(repo_name: str, rubrics_dir: str = "rubrics/manual") -> Tuple[Dict[str, str], Dict[str, int]]:
    """
    Load rubric file and extract test_id to category mapping and max scores.
    
    Args:
        repo_name: Repository name
        rubrics_dir: Directory containing rubric files
        
    Returns:
        Tuple of (categories_dict, max_scores_dict) where:
        - categories_dict maps test_id to category
        - max_scores_dict maps test_id to maximum possible score
        
    Raises:
        FileNotFoundError: If rubric file doesn't exist
        ValueError: If rubric file is invalid
    """
    rubric_path = Path(rubrics_dir) / f"{repo_name}.json"
    
    if not rubric_path.exists():
        raise FileNotFoundError(f"Rubric file not found: {rubric_path}. ")
    
    try:
        with open(rubric_path, 'r') as f:
            rubric = json.load(f)
        
        categories = {}
        max_scores = {}
        
        for test in rubric.get('tests', []):
            test_id = test.get('id')
            category = test.get('category')
            score = test.get('score', 1)
            
            if test_id and category and score is not None:
                categories[test_id] = category
                max_scores[test_id] = score
            elif not test_id:
                # Generate test_id for tests without explicit id
                test_type = test.get('type', 'unknown')
                params_hash = hash(str(test.get('params', {})))
                generated_id = f"{test_type}_{params_hash}"
                if category and score is not None:
                    categories[generated_id] = category
                    max_scores[generated_id] = score
            else:
                raise ValueError(f"Invalid test entry in rubric: {test}, missing required fields. Got test_id: {test_id}, category: {category}, score: {score}")
                
        return categories, max_scores
        
    except Exception as e:
        raise ValueError(f"Error loading rubric {rubric_path}: {e}")


def find_model_reports(repo_name: str, reports_base_dir: str = "reports-by-repo") -> List[Tuple[str, Path]]:
    """
    Find all model report files for a given repository.
    
    Args:
        repo_name: Repository name
        reports_base_dir: Base directory for reports
        
    Returns:
        List of tuples (model_name, report_path)
    """
    repo_dir = Path(reports_base_dir) / repo_name / "models"
    
    if not repo_dir.exists():
        print(f"Warning: Models directory not found: {repo_dir}")
        return []
    
    model_reports = []
    for report_file in repo_dir.glob("*_report.json"):
        model_name = report_file.stem.replace("_report", "")
        model_reports.append((model_name, report_file))
    
    return model_reports


def parse_model_report(report_path: Path, categories: Dict[str, str], max_scores: Dict[str, int]) -> Dict[str, Any]:
    """
    Parse a model report and categorize test results.
    
    Args:
        report_path: Path to the report JSON file
        categories: Mapping of test_id to category
        max_scores: Mapping of test_id to maximum possible score
        
    Returns:
        Dictionary with parsed results by category
    """
    try:
        with open(report_path, 'r') as f:
            report = json.load(f)
    except Exception as e:
        print(f"Error reading report {report_path}: {e}")
        return {}
    
    # Initialize category data
    category_data = {
        'structure': {'score': 0, 'max_score': 0, 'tests': 0, 'passed': 0},
        'configuration': {'score': 0, 'max_score': 0, 'tests': 0, 'passed': 0},
        'functionality': {'score': 0, 'max_score': 0, 'tests': 0, 'passed': 0}
    }
    
    # Parse test results
    test_results = report.get('test_results', [])
    
    for test_result in test_results:
        test_id = test_result.get('test_id', '')
        actual_score = test_result.get('score', 0)
        passed = test_result.get('passed', 0)
        
        # Determine category and max score from rubric
        if test_id not in categories:
            print(f"test id: {test_id}, categories:\n{categories}")
            raise ValueError(f"Category for test ID '{test_id}' not found in rubric for report {report_path}.")
        if test_id not in max_scores:
            print(f"test id: {test_id}, max_scores:\n{max_scores}")
            raise ValueError(f"Max score for test ID '{test_id}' not found in rubric for report {report_path}.")

        category = categories[test_id]
        test_max_score = max_scores[test_id]
        
        if category in category_data:
            category_data[category]['score'] += actual_score
            category_data[category]['max_score'] += test_max_score  # Sum max scores from rubric
            category_data[category]['tests'] += 1
            category_data[category]['passed'] += (1 if passed else 0)
    
    # Get summary data
    summary = report.get('summary', {})
    
    return {
        'category_data': category_data,
        'total_score': summary.get('total_score', 0),
        'total_max_score': summary.get('max_score', 0),
        'total_tests': summary.get('total_tests', 0),
        'passed_tests': summary.get('passed_tests', 0)
    }


def calculate_model_stats(repos: List[str], reports_base_dir: str = "reports-by-repo", rubrics_dir: str = "rubrics/manual") -> Dict[str, Any]:
    """
    Calculate comprehensive statistics for all models across given repositories.
    
    Args:
        repos: List of repository names
        reports_base_dir: Base directory for reports
        rubrics_dir: Directory containing rubric files
        
    Returns:
        Dictionary with model statistics
    """
    model_stats = defaultdict(lambda: {
        'repos': {}
    })
    
    all_models = set()
    
    for repo in repos:
        print(f"Processing repository: {repo}")
        
        # Load rubric categories and max scores
        try:
            categories, max_scores = load_rubric_categories(repo, rubrics_dir)
        except (FileNotFoundError, ValueError) as e:
            print(f"Error processing repository {repo}: {e}")
            print(f"Skipping repository {repo} due to missing or invalid rubric.")
            continue
        
        # Find model reports
        model_reports = find_model_reports(repo, reports_base_dir)
        
        for model_name, report_path in model_reports:
            all_models.add(model_name)
            
            # Parse report
            report_data = parse_model_report(report_path, categories, max_scores)
            
            if not report_data:
                continue
            
            # Store repo-specific data
            model_stats[model_name]['repos'][repo] = report_data
            
            # No need to "add to totals" - we'll calculate averages from repo-specific data later
    
    # Calculate percentages by averaging across repositories
    for model_name in all_models:
        stats = model_stats[model_name]
        
        # Calculate overall average percentage across repos
        overall_percentages = []
        for repo, repo_data in stats['repos'].items():
            if repo_data['total_max_score'] > 0:
                repo_percentage = (repo_data['total_score'] / repo_data['total_max_score']) * 100
                overall_percentages.append(repo_percentage)
        
        stats['overall_percentage'] = sum(overall_percentages) / len(overall_percentages) if overall_percentages else 0
        
        # Calculate category percentages by averaging across repos
        stats['category_percentages'] = {}
        for category in ['structure', 'configuration', 'functionality']:
            category_percentages = []
            for repo, repo_data in stats['repos'].items():
                cat_data = repo_data['category_data'][category]
                if cat_data['max_score'] > 0:
                    repo_cat_percentage = (cat_data['score'] / cat_data['max_score']) * 100
                    category_percentages.append(repo_cat_percentage)
                else:
                    # If max_score is 0, treat as 0% (no tests in this category for this repo)
                    category_percentages.append(0)
            if model_name == "ours-deepseek-deepseek-v3-0324":
                print(f"Debug: Percentage of score that {model_name} scored in per category, per repo.\nCategory: {category}, score percentages: {category_percentages}")
            stats['category_percentages'][category] = (sum(category_percentages) / len(category_percentages) 
                                                     if category_percentages else 0)
    
    return dict(model_stats)


def create_model_average_chart(model_stats: Dict[str, Any], output_dir: Path) -> None:
    """
    Create bar chart showing average percentage score for each model.
    """
    # Sort models by accuracy from worst to best (ascending order)
    model_performance = [(model, stats['overall_percentage']) for model, stats in model_stats.items()]
    model_performance.sort(key=lambda x: x[1])  # Sort by percentage (ascending)
    
    models = [item[0] for item in model_performance]
    percentages = [item[1] for item in model_performance]
    
    plt.figure(figsize=(12, 6))
    bars = plt.bar(models, percentages, color='steelblue', alpha=0.8)
    
    # Add value labels on bars
    for bar, percentage in zip(bars, percentages):
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height + 1,
                f'{percentage:.1f}%', ha='center', va='bottom')
    
    plt.title('Average Score Percentage by Model', fontsize=16, fontweight='bold')
    plt.xlabel('Model', fontsize=12)
    plt.ylabel('Average Score Percentage (%)', fontsize=12)
    plt.ylim(0, 100)
    plt.xticks(rotation=45, ha='right')
    plt.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    
    plt.savefig(output_dir / 'model_average_scores.png', dpi=300, bbox_inches='tight')
    plt.close()


def create_category_charts(model_stats: Dict[str, Any], output_dir: Path) -> None:
    """
    Create bar charts showing category performance for each model.
    """
    categories = ['structure', 'configuration', 'functionality']
    
    for model_name, stats in model_stats.items():
        model_dir = output_dir / model_name
        model_dir.mkdir(exist_ok=True)
        
        percentages = [stats['category_percentages'][cat] for cat in categories]
        
        plt.figure(figsize=(10, 6))
        bars = plt.bar(categories, percentages, 
                      color=['#FF6B6B', '#4ECDC4', '#45B7D1'], alpha=0.8)
        
        # Add value labels
        for bar, percentage in zip(bars, percentages):
            height = bar.get_height()
            plt.text(bar.get_x() + bar.get_width()/2., height + 1,
                    f'{percentage:.1f}%', ha='center', va='bottom')
        
        plt.title(f'Category Performance - {model_name}', fontsize=16, fontweight='bold')
        plt.xlabel('Category', fontsize=12)
        plt.ylabel('Score Percentage (%)', fontsize=12)
        plt.ylim(0, 100)
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        
        plt.savefig(model_dir / 'category_performance.png', dpi=300, bbox_inches='tight')
        plt.close()


def create_comprehensive_category_chart(model_stats: Dict[str, Any], repos: List[str], 
                                      output_dir: Path) -> None:
    """
    Create comprehensive bar chart with all repos and categories for each model.
    """
    categories = ['structure', 'configuration', 'functionality']
    category_colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
    
    for model_name, stats in model_stats.items():
        model_dir = output_dir / model_name
        model_dir.mkdir(exist_ok=True)
        
        # Prepare data
        repo_data = []
        for repo in repos:
            if repo in stats['repos']:
                repo_percentages = []
                for category in categories:
                    cat_data = stats['repos'][repo]['category_data'][category]
                    if cat_data['max_score'] > 0:
                        percentage = (cat_data['score'] / cat_data['max_score']) * 100
                    else:
                        percentage = 0
                    repo_percentages.append(percentage)
                repo_data.append(repo_percentages)
            else:
                repo_data.append([0, 0, 0])  # No data for this repo
        
        # Create chart
        x = np.arange(len(repos))
        width = 0.25
        
        fig, ax = plt.subplots(figsize=(15, 8))
        
        for i, category in enumerate(categories):
            values = [repo_data[j][i] for j in range(len(repos))]
            offset = (i - 1) * width
            bars = ax.bar(x + offset, values, width, label=category.title(), 
                         color=category_colors[i], alpha=0.8)
            
            # Add value labels
            for bar, value in zip(bars, values):
                height = bar.get_height()
                if height > 0:
                    ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                           f'{value:.0f}%', ha='center', va='bottom', fontsize=9)
        
        ax.set_title(f'Performance by Repository and Category - {model_name}', 
                     fontsize=16, fontweight='bold')
        ax.set_xlabel('Repository', fontsize=12)
        ax.set_ylabel('Score Percentage (%)', fontsize=12)
        ax.set_ylim(0, 110)
        ax.set_xticks(x)
        ax.set_xticklabels(repos, rotation=45, ha='right')
        ax.legend()
        ax.grid(axis='y', alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(model_dir / 'comprehensive_performance.png', dpi=300, bbox_inches='tight')
        plt.close()


def create_error_pie_charts(model_stats: Dict[str, Any], output_dir: Path) -> None:
    """
    Create bar charts showing error composition for each model.
    """
    categories = ['structure', 'configuration', 'functionality']
    category_colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
    
    for model_name, stats in model_stats.items():
        model_dir = output_dir / model_name
        model_dir.mkdir(exist_ok=True)
        
        # Calculate error percentages (percentage points lost in each category)
        error_percentages = []
        for category in categories:
            category_percentage = stats['category_percentages'][category]
            error_percentage = 100 - category_percentage  # Points lost
            error_percentages.append(error_percentage)
        
        # Create bar chart
        fig, ax = plt.subplots(figsize=(10, 6))
        
        bars = ax.bar(categories, error_percentages, color=category_colors, alpha=0.8)
        
        # Add value labels on bars
        for bar, error_pct in zip(bars, error_percentages):
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                   f'{error_pct:.1f}%', ha='center', va='bottom')
        
        # Customize the chart
        ax.set_title(f'Error Distribution - {model_name}', 
                     fontsize=16, fontweight='bold')
        ax.set_xlabel('Category', fontsize=12)
        ax.set_ylabel('Error Percentage (%)', fontsize=12)
        ax.set_ylim(0, 110)
        ax.grid(axis='y', alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(model_dir / 'error_distribution.png', dpi=300, bbox_inches='tight')
        plt.close()


def create_repo_composition_comparison(model_stats: Dict[str, Any], repos: List[str], output_dir: Path) -> None:
    """
    Create ring pie charts comparing original vs modified score compositions for specific repositories.
    """
    # Original score compositions (hardcoded reference values)
    original_compositions = {
        'BurntSushi_ripgrep': {
            'structure': 36,
            'configuration': 40,
            'functionality': 5
        },
        'Baleen': {
            'structure': 25,
            'configuration': 33,
            'functionality': 12
        },
        'Fairify': {
            'structure': 41,
            'configuration': 18,
            'functionality': 13
        }
    }

    target_repos = list(original_compositions.keys())
    available_repos = [repo for repo in repos if repo in target_repos]
    if len(available_repos) < len(target_repos):
        print(f"Warning: Some target repositories for composition comparison are missing reports. Found {len(available_repos)} / {len(target_repos)}")
        return
    
    # Create figure with subplots for each repo pair
    n_repos = len(available_repos)
    fig, axes = plt.subplots(2, n_repos, figsize=(6*n_repos, 10))
    
    # Handle single repo case
    if n_repos == 1:
        axes = axes.reshape(2, 1)
    
    categories = ['structure', 'configuration', 'functionality']
    category_colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
    
    for col, repo in enumerate(available_repos):
        # Calculate current (modified) composition from any available model
        # Use the first available model's data for this repo
        current_composition = {'structure': 0, 'configuration': 0, 'functionality': 0}
        
        # Find a model that has data for this repo
        sample_model = None
        for model_name, stats in model_stats.items():
            if repo in stats['repos']:
                sample_model = model_name
                break
        
        if sample_model:
            repo_data = model_stats[sample_model]['repos'][repo]['category_data']
            for category in categories:
                current_composition[category] = repo_data[category]['max_score']
        else:
            print(f"  Warning: No model data found for repo {repo}")
            continue
        
        # Original composition
        original = original_compositions[repo]
        orig_values = [original[cat] for cat in categories]
        orig_total = sum(orig_values)
        
        # Current composition  
        current_values = [current_composition[cat] for cat in categories]
        current_total = sum(current_values)
        
        # Create original pie chart (top row)
        if orig_total > 0:
            wedges, texts, autotexts = axes[0, col].pie(
                orig_values, labels=categories, colors=category_colors,
                autopct=lambda pct, allvals=orig_values: f'{int(pct/100*sum(allvals))}',
                startangle=90, wedgeprops=dict(width=0.5)
            )
            axes[0, col].set_title(f'{repo}\nOriginal (Total: {orig_total})', 
                                  fontsize=12, fontweight='bold')
        
        # Create current pie chart (bottom row)
        if current_total > 0:
            wedges, texts, autotexts = axes[1, col].pie(
                current_values, labels=categories, colors=category_colors,
                autopct=lambda pct, allvals=current_values: f'{int(pct/100*sum(allvals))}',
                startangle=90, wedgeprops=dict(width=0.5)
            )
            axes[1, col].set_title(f'Modified (Total: {current_total})', 
                                  fontsize=12, fontweight='bold')
        
        # Print comparison
        print(f"\n  {repo} Score Composition:")
        print(f"    Original  - Structure: {original['structure']}, Configuration: {original['configuration']}, Functionality: {original['functionality']} (Total: {orig_total})")
        print(f"    Modified  - Structure: {current_composition['structure']}, Configuration: {current_composition['configuration']}, Functionality: {current_composition['functionality']} (Total: {current_total})")
        
        total_change = current_total - orig_total
        print(f"    Change: {'+' if total_change >= 0 else ''}{total_change} points")
    
    plt.suptitle('Repository Score Composition: Original vs Modified', 
                 fontsize=16, fontweight='bold', y=0.95)
    plt.tight_layout()
    plt.subplots_adjust(top=0.90)
    
    plt.savefig(output_dir / 'repo_composition_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()


def create_detailed_test_comparison(model_stats: Dict[str, Any], repos: List[str], 
                                  reports_base_dir: str = "reports-by-repo", 
                                  rubrics_dir: str = "rubrics/manual",
                                  output_dir: Path = None) -> None:
    """
    Create detailed heatmap showing individual test performance for each model.
    
    Args:
        model_stats: Model statistics dictionary
        repos: List of repository names
        reports_base_dir: Base directory for reports
        rubrics_dir: Directory containing rubric files
        output_dir: Output directory for charts
    """
    import matplotlib.colors as mcolors
    
    # Order models according to target_strings pairing
    target_strings = ["opus4", "35haiku", "gpt41", "gpt41mini"]
    ordered_models = []
    
    # First, add paired models (baseline + ours) for each target string
    for target in target_strings:
        baseline_model = None
        ours_model = None
        
        # Find matching pairs
        for model_name in model_stats.keys():
            if target in model_name:
                if "ours" in model_name:
                    ours_model = model_name
                else:
                    baseline_model = model_name
        
        # Add baseline model first, then ours model
        if baseline_model and ours_model:
            ordered_models.append(baseline_model)
            ordered_models.append(ours_model)
    
    # Then add all other models that don't contain target strings
    other_models = [model for model in model_stats.keys() 
                   if model not in ordered_models]
    ordered_models.extend(other_models)
    
    # Use ordered_models instead of model_names
    model_names = ordered_models
    n_models = len(model_names)
    
    for repo in repos:
        print(f"  Creating detailed test comparison heatmap for repository: {repo}")
        
        try:
            # Load rubric to get test information
            categories, max_scores = load_rubric_categories(repo, rubrics_dir)
        except (FileNotFoundError, ValueError) as e:
            print(f"    Warning: Could not load rubric for {repo}: {e}")
            continue
        
        # Collect test data from all models for this repo
        test_data = {}  # test_id -> {model_name -> (score, max_score)}
        all_test_ids = set()
        
        # Find model reports for this repo
        model_reports = find_model_reports(repo, reports_base_dir)
        
        for model_name, report_path in model_reports:
            try:
                with open(report_path, 'r') as f:
                    report = json.load(f)
                
                test_results = report.get('test_results', [])
                
                for test_result in test_results:
                    test_id = test_result.get('test_id', '')
                    actual_score = test_result.get('score', 0)
                    
                    # Ensure test_id exists in rubric
                    if test_id not in max_scores:
                        raise ValueError(f"Test ID '{test_id}' not found in rubric for repository {repo}, model {model_name}. "
                                       f"This indicates a mismatch between the evaluation report and rubric file.")
                    
                    test_max_score = max_scores[test_id]
                    
                    if test_id not in test_data:
                        test_data[test_id] = {}
                    
                    test_data[test_id][model_name] = (actual_score, test_max_score)
                    all_test_ids.add(test_id)
                    
            except Exception as e:
                print(f"    Warning: Could not process report {report_path}: {e}")
                continue
        
        if not test_data:
            print(f"    Warning: No test data found for repository {repo}")
            continue
        
        # Sort test IDs for consistent ordering and group by category
        sorted_test_ids = sorted(all_test_ids)
        n_tests = len(sorted_test_ids)
        
        if n_tests == 0:
            print(f"    Warning: No tests found for repository {repo}")
            continue
        
        # Create heatmap data matrix
        # Rows: models, Columns: tests
        heatmap_data = np.zeros((n_models, n_tests))
        
        for i, model_name in enumerate(model_names):
            for j, test_id in enumerate(sorted_test_ids):
                if model_name in test_data.get(test_id, {}):
                    score, max_score = test_data[test_id][model_name]
                    percentage = (score / max_score * 100) if max_score > 0 else 0
                else:
                    percentage = 0  # Model didn't have data for this test
                heatmap_data[i, j] = percentage
        
        # Create the heatmap
        fig_width = max(12, n_tests * 0.8)  # Scale with number of tests
        fig_height = max(8, n_models * 0.6)   # Scale with number of models
        fig, ax = plt.subplots(figsize=(fig_width, fig_height))
        
        # Create custom orange colormap (white for 0, bright orange for 100)
        # Using reversed oranges colormap so brighter = less score (white for zero)
        colors = ['#FFFFFF', '#FFF4E6', '#FFE4CC', '#FFD4B3', '#FFC299', 
                  '#FFB180', '#FF9F66', '#FF8E4D', '#FF7C33', '#FF6B1A', '#FF5500']
        n_bins = 100
        cmap = mcolors.LinearSegmentedColormap.from_list('orange_reversed', colors, N=n_bins)
        
        # Plot heatmap
        im = ax.imshow(heatmap_data, cmap=cmap, aspect='auto', vmin=0, vmax=100)
        
        # Add visual separators between model groups
        separator_positions = []
        
        # Calculate separator positions based on pairing logic
        current_pos = 0
        for target in target_strings:
            baseline_model = None
            ours_model = None
            
            # Find matching pairs
            for model_name in model_stats.keys():
                if target in model_name:
                    if "ours" in model_name:
                        ours_model = model_name
                    else:
                        baseline_model = model_name
            
            # If we found a pair, move position by 2 and add separator
            if baseline_model and ours_model:
                current_pos += 2
                separator_positions.append(current_pos - 0.5)
        
        # Add separator before individual models (if any exist)
        other_models = [model for model in model_stats.keys() 
                       if model not in ordered_models[:current_pos]]
        if other_models:
            separator_positions.append(current_pos - 0.5)
        
        # Draw horizontal lines as separators
        for sep_pos in separator_positions:
            if sep_pos < n_models - 0.5:  # Don't draw line after the last row
                ax.axhline(y=sep_pos, color='black', linewidth=2, alpha=0.8)
        
        # Set ticks and labels
        ax.set_xticks(range(n_tests))
        ax.set_yticks(range(n_models))
        
        # Create test labels with category information
        test_labels = []
        for test_id in sorted_test_ids:
            category = categories.get(test_id, 'unknown')
            test_labels.append(f"{test_id}\n({category})")
        
        ax.set_xticklabels(test_labels, rotation=45, ha='right', fontsize=8)
        ax.set_yticklabels(model_names, fontsize=9)
        
        # Add text annotations with percentage values
        for i in range(n_models):
            for j in range(n_tests):
                percentage = heatmap_data[i, j]
                # Only show text if percentage is high enough for visibility
                if percentage > 20:
                    text_color = 'black' if percentage > 50 else 'white'
                    ax.text(j, i, f'{percentage:.0f}%', ha='center', va='center',
                           color=text_color, fontsize=7, fontweight='bold')
        
        # Customize the chart
        ax.set_xlabel('Test ID', fontsize=12)
        ax.set_ylabel('Model', fontsize=12)
        ax.set_title(f'Test Performance Heatmap - {repo}', 
                     fontsize=16, fontweight='bold', pad=20)
        
        # Add colorbar
        cbar = plt.colorbar(im, ax=ax, shrink=0.8)
        cbar.set_label('Score Percentage (%)', rotation=270, labelpad=20, fontsize=12)
        
        # Adjust layout to prevent clipping
        plt.tight_layout()
        
        # Save the chart
        repo_output_dir = output_dir / repo
        repo_output_dir.mkdir(exist_ok=True)
        
        plt.savefig(repo_output_dir / f'{repo}_detailed_test_heatmap.png', 
                   dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"    Created detailed test heatmap: {repo_output_dir / f'{repo}_detailed_test_heatmap.png'}")


def create_ours_vs_baseline_comparison(model_stats: Dict[str, Any], output_dir: Path) -> None:
    """
    Create side-by-side comparison of "ours" methods vs baseline methods.
    Compares error rates for models containing specific identifiers.
    """
    target_strings = ["opus4", "35haiku", "gpt41", "gpt41mini"]
    comparison_pairs = {}
    
    # Find matching pairs
    for target in target_strings:
        ours_model = None
        baseline_model = None
        
        for model_name in model_stats.keys():
            if target in model_name:
                if "ours" in model_name:
                    ours_model = model_name
                else:
                    baseline_model = model_name
        
        if ours_model is None or baseline_model is None:
            raise ValueError(f"Missing pair for '{target}': found ours='{ours_model}', baseline='{baseline_model}'. "
                           f"Expected to find both 'ours' and non-'ours' models containing '{target}'.")
        
        comparison_pairs[target] = {
            'ours': ours_model,
            'baseline': baseline_model
        }
    
    # Prepare data for plotting
    targets = list(comparison_pairs.keys())
    ours_accuracies = [model_stats[comparison_pairs[target]['ours']]['overall_percentage'] for target in targets]
    baseline_accuracies = [model_stats[comparison_pairs[target]['baseline']]['overall_percentage'] for target in targets]
    
    # Create the comparison chart
    x = np.arange(len(targets))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    bars1 = ax.bar(x - width/2, baseline_accuracies, width, label='Baseline', color='#FF6B6B', alpha=0.8)
    bars2 = ax.bar(x + width/2, ours_accuracies, width, label='Ours', color='#4ECDC4', alpha=0.8)
    
    # Add value labels on bars
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                   f'{height:.1f}%', ha='center', va='bottom')
    
    # Customize the chart
    ax.set_xlabel('Model Type', fontsize=12)
    ax.set_ylabel('Accuracy (%)', fontsize=12)
    ax.set_title('Accuracy Comparison: Baseline vs Ours Methods', fontsize=16, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([target.upper() for target in targets])
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    # Add improvement annotations
    for i, target in enumerate(targets):
        baseline_acc = baseline_accuracies[i]
        ours_acc = ours_accuracies[i]
        improvement = ours_acc - baseline_acc
        if improvement > 0:
            ax.annotate(f'↑{improvement:.1f}pp', 
                       xy=(i, max(baseline_acc, ours_acc) + 2),
                       ha='center', va='bottom', 
                       fontweight='bold', color='green')
        elif improvement < 0:
            ax.annotate(f'↓{abs(improvement):.1f}pp', 
                       xy=(i, max(baseline_acc, ours_acc) + 2),
                       ha='center', va='bottom', 
                       fontweight='bold', color='red')
    
    plt.tight_layout()
    plt.savefig(output_dir / 'ours_vs_baseline_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # Print summary
    print("\nOurs vs Baseline Comparison:")
    for target in targets:
        ours_acc = model_stats[comparison_pairs[target]['ours']]['overall_percentage']
        baseline_acc = model_stats[comparison_pairs[target]['baseline']]['overall_percentage']
        improvement = ours_acc - baseline_acc
        print(f"  {target.upper()}: Baseline {baseline_acc:.1f}% vs Ours {ours_acc:.1f}% "
              f"({'+'if improvement >= 0 else ''}{improvement:.1f}pp)")


def create_combined_error_visualization(model_stats: Dict[str, Any], output_dir: Path) -> None:
    """
    Create a combined visualization with all model error bar charts.
    """
    models = list(model_stats.keys())
    n_models = len(models)
    
    # Calculate grid dimensions
    cols = min(3, n_models)
    rows = (n_models + cols - 1) // cols
    
    fig, axes = plt.subplots(rows, cols, figsize=(5*cols, 4*rows))
    
    # Handle different subplot configurations
    if n_models == 1:
        axes = [axes]
    elif rows == 1 and cols == 1:
        axes = [axes]
    elif rows == 1 or cols == 1:
        # Already a 1D array, ensure it's a list
        axes = list(axes) if hasattr(axes, '__iter__') else [axes]
    else:
        axes = axes.flatten()
    
    categories = ['structure', 'configuration', 'functionality']
    category_colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
    
    for idx, model_name in enumerate(models):
        stats = model_stats[model_name]
        ax = axes[idx]
        
        # Calculate error percentages
        error_percentages = []
        for category in categories:
            category_percentage = stats['category_percentages'][category]
            error_percentage = 100 - category_percentage  # Points lost
            error_percentages.append(error_percentage)
        
        # Create bar chart
        bars = ax.bar(categories, error_percentages, color=category_colors, alpha=0.8)
        
        # Add value labels on bars (only if there's enough space)
        for bar, error_pct in zip(bars, error_percentages):
            height = bar.get_height()
            if height > 5:  # Only show label if bar is tall enough
                ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                       f'{error_pct:.0f}%', ha='center', va='bottom', fontsize=8)
        
        ax.set_title(model_name, fontsize=12, fontweight='bold')
        ax.set_ylim(0, 105)
        ax.set_ylabel('Error %', fontsize=10)
        ax.grid(axis='y', alpha=0.3)
        ax.tick_params(axis='x', labelsize=8)
        ax.tick_params(axis='y', labelsize=8)
    
    # Hide empty subplots
    for idx in range(n_models, len(axes)):
        axes[idx].set_visible(False)
    
    plt.suptitle('Error Distribution Comparison Across Models', 
                 fontsize=16, fontweight='bold', y=0.95)
    plt.tight_layout()
    
    plt.savefig(output_dir / 'combined_error_distributions.png', 
                dpi=300, bbox_inches='tight')
    plt.close()


def collect_zero_scored_evals(repos: List[str], reports_base_dir: str = "reports-by-repo", 
                             output_dir: Path = None) -> None:
    """
    Collect and save information about evaluations that scored zero.
    
    Args:
        repos: List of repository names
        reports_base_dir: Base directory for reports
        output_dir: Output directory to save the zero_scored_evals.txt file
    """
    zero_scored_evals = []
    
    for repo in repos:
        # Find model reports for this repo
        model_reports = find_model_reports(repo, reports_base_dir)
        
        for model_name, report_path in model_reports:
            try:
                with open(report_path, 'r') as f:
                    report = json.load(f)
                
                # Check summary total score
                summary = report.get('summary', {})
                total_score = summary.get('total_score', 0)
                
                if total_score == 0:
                    zero_scored_evals.append(f"{model_name} {repo}")
                    
            except Exception as e:
                print(f"Warning: Could not process report {report_path}: {e}")
                continue
    
    # Save zero-scored evaluations to file
    if output_dir:
        zero_scored_file = output_dir / "zero_scored_evals.txt"
        with open(zero_scored_file, 'w') as f:
            for eval_entry in zero_scored_evals:
                f.write(f"{eval_entry}\n")
        
        print(f"  Found {len(zero_scored_evals)} zero-scored evaluations")
        if zero_scored_evals:
            print(f"  Saved to: {zero_scored_file}")


def generate_summary_report(model_stats: Dict[str, Any], repos: List[str], 
                           output_dir: Path) -> None:
    """
    Generate a comprehensive summary report in JSON format.
    """
    summary = {
        'repositories_analyzed': repos,
        'models_analyzed': list(model_stats.keys()),
        'model_rankings': [],
        'category_analysis': {},
        'detailed_stats': model_stats
    }
    
    # Model rankings by overall percentage
    rankings = [(model, stats['overall_percentage']) 
                for model, stats in model_stats.items()]
    rankings.sort(key=lambda x: x[1], reverse=True)
    summary['model_rankings'] = [{'model': model, 'score_percentage': score} 
                                for model, score in rankings]
    
    # Category analysis
    categories = ['structure', 'configuration', 'functionality']
    for category in categories:
        cat_rankings = [(model, stats['category_percentages'][category]) 
                       for model, stats in model_stats.items()]
        cat_rankings.sort(key=lambda x: x[1], reverse=True)
        summary['category_analysis'][category] = {
            'best_model': cat_rankings[0][0] if cat_rankings else None,
            'best_score': cat_rankings[0][1] if cat_rankings else 0,
            'rankings': [{'model': model, 'score_percentage': score} 
                        for model, score in cat_rankings]
        }
    
    # Save summary
    with open(output_dir / 'summary_report.json', 'w') as f:
        json.dump(summary, f, indent=2)


def main():
    parser = argparse.ArgumentParser(
        description="Generate statistics and visualizations from EnvEval reports",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python generate_stats.py --repos Fairify ELECT --output-dir results
  python generate_stats.py --all-repos --output-dir comprehensive-analysis
  python generate_stats.py --repos Fairify --verbose
        """
    )
    
    repo_group = parser.add_mutually_exclusive_group(required=True)
    repo_group.add_argument("--repos", nargs="+", help="List of repository names to analyze")
    repo_group.add_argument("--all-repos", action="store_true", 
                           help="Analyze all available repositories with reports")
    
    parser.add_argument("--reports-dir", default="reports-by-repo",
                       help="Directory containing repository reports (default: reports-by-repo)")
    parser.add_argument("--rubrics-dir", default="rubrics/manual",
                       help="Directory containing rubric files (default: rubrics/manual)")
    parser.add_argument("--output-dir", default="overview-stats",
                       help="Output directory for statistics and visualizations (default: overview-stats)")
    parser.add_argument("--verbose", action="store_true",
                       help="Enable verbose output")
    
    args = parser.parse_args()
    
    # Discover repositories if --all-repos is specified
    if args.all_repos:
        args.repos = discover_available_repos(args.reports_dir)
        if not args.repos:
            print(f"No repositories with reports found in {args.reports_dir}")
            sys.exit(1)
        print(f"Auto-discovered repositories: {', '.join(args.repos)}")
    
    # Setup output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    print(f"Analyzing repositories: {', '.join(args.repos)}")
    print(f"Reports directory: {args.reports_dir}")
    print(f"Rubrics directory: {args.rubrics_dir}")
    print(f"Output directory: {output_dir}")
    print("-" * 60)
    
    # Calculate statistics
    print("Calculating model statistics...")
    model_stats = calculate_model_stats(args.repos, args.reports_dir, args.rubrics_dir)
    
    if not model_stats:
        print("No model statistics found. Check that reports exist.")
        sys.exit(1)
    
    print(f"Found {len(model_stats)} models: {', '.join(model_stats.keys())}")
    
    # Generate visualizations
    print("\nGenerating visualizations...")
    
    # 1. Model average chart
    print("  Creating model average scores chart...")
    create_model_average_chart(model_stats, output_dir)
    
    # 2. Category charts for each model
    print("  Creating category performance charts...")
    create_category_charts(model_stats, output_dir)
    
    # 3. Comprehensive category chart for each model
    print("  Creating comprehensive performance charts...")
    create_comprehensive_category_chart(model_stats, args.repos, output_dir)
    
    # 4. Error pie charts for each model
    print("  Creating error distribution charts...")
    create_error_pie_charts(model_stats, output_dir)
    
    # 5. Combined error visualization
    print("  Creating combined error visualization...")
    create_combined_error_visualization(model_stats, output_dir)
    
    # 6. Ours vs Baseline comparison
    print("  Creating ours vs baseline comparison...")
    try:
        create_ours_vs_baseline_comparison(model_stats, output_dir)
    except ValueError as e:
        print(f"  Warning: Could not create ours vs baseline comparison: {e}")
    
    # 7. Repository composition comparison
    print("  Creating repository composition comparison...")
    create_repo_composition_comparison(model_stats, args.repos, output_dir)
    
    # 8. Detailed test comparison for each repository
    print("  Creating detailed test comparisons...")
    create_detailed_test_comparison(model_stats, args.repos, args.reports_dir, args.rubrics_dir, output_dir)

    # 9. Collect zero-scored evaluations
    print("  Collecting zero-scored evaluations...")
    collect_zero_scored_evals(args.repos, args.reports_dir, output_dir)

    # Generate summary report
    print("  Creating summary report...")
    generate_summary_report(model_stats, args.repos, output_dir)
    
    print(f"\nAll visualizations saved to: {output_dir}")
    print("Generated files:")
    print(f"  - model_average_scores.png")
    print(f"  - combined_error_distributions.png")
    print(f"  - ours_vs_baseline_comparison.png")
    print(f"  - repo_composition_comparison.png")
    print(f"  - summary_report.json")
    print(f"  - zero_scored_evals.txt")
    print(f"  - For each model: {output_dir}/[model_name]/")
    print(f"    - category_performance.png")
    print(f"    - comprehensive_performance.png")
    print(f"    - error_distribution.png")
    print(f"  - For each repository: {output_dir}/[repo_name]/")
    print(f"    - [repo_name]_detailed_test_heatmap.png")


if __name__ == "__main__":
    main()