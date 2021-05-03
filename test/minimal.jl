using TSXPlayground.TSX

function f()
    x = 0
    if (status = TSX.xbegin()) == TSX.XBEGIN_STARTED
        x = 1
        TSX.xend()
    end
    return (x, status)
end
