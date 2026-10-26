// RecipePreview: HelloQuickLookExtensions' view-based Quick Look Preview extension (like Xcode's Quick Look Preview
// Extension template): it reads a .recipe (JSON) and lays out its title and ingredients.
import UIKit
import QuickLook

struct Recipe: Decodable {
    var title: String
    var serves: Int
    var ingredients: [String]
}

class PreviewViewController: UIViewController, QLPreviewingController {
    let titleLabel = UILabel()
    let servesLabel = UILabel()
    let list = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 1, green: 0.97, blue: 0.9, alpha: 1)
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.accessibilityIdentifier = "recipe-title"
        servesLabel.font = .systemFont(ofSize: 17)
        servesLabel.textColor = .systemBrown
        list.numberOfLines = 0
        list.font = .systemFont(ofSize: 20)
        list.accessibilityIdentifier = "recipe-ingredients"
        let stack = UIStackView(arrangedSubviews: [titleLabel, servesLabel, list])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
        ])
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: url))
            loadViewIfNeeded()
            titleLabel.text = recipe.title
            servesLabel.text = "Serves \(recipe.serves)"
            list.text = recipe.ingredients.map { "• " + $0 }.joined(separator: "\n")
            print("qlx recipe prepared \(recipe.title) ingredients \(recipe.ingredients.count)")
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
