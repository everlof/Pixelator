import UIKit

protocol Pixable {

    var height: Int { get }

    var width: Int { get }

    func color(at point: CGPoint, isEnabled: Bool) -> CGColor

}

struct Rainbow: Pixable {

    var height: Int {
        return 100
    }

    var width: Int {
        return 100
    }

    func color(at point: CGPoint, isEnabled: Bool) -> CGColor {
        let maxDistance = sqrt(CGFloat(height) * CGFloat(height) + CGFloat(width) * CGFloat(width))
        let red = CGFloat(point.y) / CGFloat(height)
        let green = CGFloat(point.x) / CGFloat(width)
        let distance = sqrt(point.y * point.y + point.x * point.x)
        let blue = 1 - ( distance / maxDistance )

        if isEnabled {
            return UIColor(red: red, green: green, blue: blue, alpha: 1.0).cgColor
        } else {
            let average = ( red + green + blue ) / 3
            return UIColor(red: average, green: average, blue: average, alpha: 1.0).cgColor
        }
    }

}

class PixelView: UIView, UIGestureRecognizerDelegate {

    struct State {
        var toggled = false
    }

    var layers: [[CAShapeLayer]]

    var states: [[State]]

    let pixable: Pixable

    let tapGesture = UITapGestureRecognizer()

    let pinchGesture = UIPinchGestureRecognizer()

    let panGesture = UIPanGestureRecognizer()

    var lastScale: CGFloat = 1.0

    var lastPosition: CGPoint = .zero

    init(pixable: Pixable) {
        self.pixable = pixable

        layers = [[CAShapeLayer]]()
        states = [[State]]()

        for _ in 0..<(pixable.height) {
            var array = [CAShapeLayer]()
            var stateArray = [State]()

            for _ in 0..<(pixable.width) {
                let shapeLayer = CAShapeLayer()
                array.append(shapeLayer)
                stateArray.append(State())

            }

            layers.append(array)
            states.append(stateArray)
        }

        super.init(frame: .zero)

        layers.forEach { layers in
            layers.forEach { layer in
                self.layer.addSublayer(layer)
            }
        }

        addGestureRecognizer(tapGesture)
        addGestureRecognizer(pinchGesture)
        addGestureRecognizer(panGesture)

        tapGesture.addTarget(self, action: #selector(didTap(gesture:)))
        tapGesture.delegate = self

        pinchGesture.addTarget(self, action: #selector(pinch(gesture:)))
        pinchGesture.delegate = self

        panGesture.addTarget(self, action: #selector(pan(gesture:)))
        panGesture.delegate = self

        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    @objc func didTap(gesture: UITapGestureRecognizer) {
        print("tap = \(gesture.location(in: self))")

        if gesture.state == .ended {
            let location = gesture.location(in: self).applying(fromPixable.inverted())
            let y = Int(floor(location.y))
            let x = Int(floor(location.x))
            states[y][x].toggled = !states[y][x].toggled
            layers[y][x].fillColor = pixable.color(at: CGPoint(x: x, y: y), isEnabled: states[y][x].toggled)
        }
    }

    var fromPixable: CGAffineTransform {
        let scaleX = bounds.width / CGFloat(pixable.width)
        let scaleY = bounds.height / CGFloat(pixable.height)
        return CGAffineTransform.identity.scaledBy(x: scaleX, y: scaleY)
    }

    @objc func pan(gesture: UIPanGestureRecognizer) {
        print("pan = \(lastPosition)")

        if gesture.state == .began {
            lastPosition = gesture.location(in: self)
        }

        if gesture.state == .changed {
            let location = gesture.location(in: self)
            let offset = CGPoint(x: location.x - lastPosition.x,
                                 y: location.y - lastPosition.y)

            transform = transform.translatedBy(x: offset.x, y: offset.y)
            lastPosition = gesture.location(in: self)
        }
    }

    @objc func pinch(gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            lastScale = gesture.scale
            lastPosition = gesture.location(in: self)
        }


        if gesture.state == .began || gesture.state == .changed {
            // Scaling
            let currentScale = layer.value(forKeyPath: "transform.scale") as! CGFloat

            let maxScale: CGFloat = 10.0
            let minScale: CGFloat = 1.0

            var newScale = 1 - (lastScale - gesture.scale)
            newScale = min(newScale, maxScale / currentScale)
            newScale = max(newScale, minScale / currentScale)

            // Translation
            let location = gesture.location(in: self)
            let offset = CGPoint(x: location.x - lastPosition.x,
                                 y: location.y - lastPosition.y)

            let pinchCenter = CGPoint(x: location.x - bounds.midX,
                                      y: location.y - bounds.midY)

            transform = transform
                .translatedBy(x: pinchCenter.x, y: pinchCenter.y)
                .scaledBy(x: newScale, y: newScale)
                .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)
                .translatedBy(x: offset.x, y: offset.y)

            print("newScale=\(newScale), offset = \(offset)")

            lastScale = gesture.scale
            lastPosition = gesture.location(in: self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layers.enumerated().forEach { (h, layers) in
            layers.enumerated().forEach({ (w, layer) in
                layer.frame = bounds
                layer.path = UIBezierPath(rect: CGRect(x: w, y: h, width: 1, height: 1).applying(fromPixable)).cgPath
                layer.fillColor = pixable.color(at: CGPoint(x: w, y: h), isEnabled: states[h][w].toggled)
            })
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class ViewController: UIViewController {

    let pixelView = PixelView(pixable: Rainbow())

    override func viewDidLoad() {
        super.viewDidLoad()
        pixelView.backgroundColor = .lightGray
        pixelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pixelView)
        pixelView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        pixelView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100).isActive = true
        pixelView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        pixelView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

}

