import UIKit
import PlaygroundSupport

let imageView = UIImageView(image: #imageLiteral(resourceName: "IMG_0032.JPG"))
imageView.contentMode = .scaleAspectFit
let label = UILabel()
label.textAlignment = .center
label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
label.text = "class: confidence"
let stackView = UIStackView(arrangedSubviews: [imageView, label])
stackView.axis = .vertical
PlaygroundPage.current.liveView = stackView
