module TSX

# https://gcc.gnu.org/onlinedocs/gcc/x86-transactional-memory-intrinsics.html

export @xabort, xbegin, xend, xtest, xabort, xabort_code, XBEGIN_STARTED, XABORT_EXPLICIT

const XBEGIN_STARTED = Int32(-1)
const XABORT_EXPLICIT = Int32(1 << 0)
const XABORT_RETRY = Int32(1 << 1)
const XABORT_CONFLICT = Int32(1 << 2)
const XABORT_CAPACITY = Int32(1 << 3)
const XABORT_DEBUG = Int32(1 << 4)
const XABORT_NESTED = Int32(1 << 5)

is_explicit(code) = (code & XABORT_EXPLICIT) != 0
is_retry(code) = (code & XABORT_RETRY) != 0
is_conflict(code) = (code & XABORT_CONFLICT) != 0

@inline function xbegin()
    Base.llvmcall(
        (
            """
            define i32 @entry() #0 {
            top:
                %0 = call i32 @llvm.x86.xbegin() #1
                ret i32 %0
            }

            declare i32 @llvm.x86.xbegin() #1

            attributes #0 = { alwaysinline }
            attributes #1 = { nounwind }
            """,
            "entry",
        ),
        Int32,
        Tuple{},
    )
end

@inline function xend()
    Base.llvmcall(
        (
            """
            define void @entry() #0 {
            top:
                call void @llvm.x86.xend() #1
                ret void
            }

            declare void @llvm.x86.xend() #1

            attributes #0 = { alwaysinline }
            attributes #1 = { nounwind }
            """,
            "entry",
        ),
        Cvoid,
        Tuple{},
    )
end

@inline function xtest()
    Base.llvmcall(
        (
            """
            define i32 @entry() #0 {
            top:
                %0 = call i32 @llvm.x86.xtest() #1
                ret i32 %0
            }

            declare i32 @llvm.x86.xtest() #1

            attributes #0 = { alwaysinline }
            attributes #1 = { nounwind }
            """,
            "entry",
        ),
        Int32,
        Tuple{},
    )
end

macro xabort(status::Signed)
    typemin(Int8) <= status <= typemax(Int8) || error("require an 8-bit signed integer")
    :(xabort(Val{$status}()))
end

@generated function xabort(::Val{status}) where {status}
    (status isa Signed && typemin(Int8) <= status <= typemax(Int8)) ||
        return :(error("require an 8-bit signed integer"))
    IR = (
        """
        define void @entry() #0 {
        top:
            call void @llvm.x86.xabort(i8 $status) #1
            ret void
        }

        declare void @llvm.x86.xabort(i8) #1

        attributes #0 = { alwaysinline }
        attributes #1 = { nounwind }
        """,
        "entry",
    )
    quote
        $(Expr(:meta, :inline))
        Base.llvmcall($IR, Cvoid, Tuple{})
    end
end

@inline xabort_code(status::Int32) = ((status >> 24) & 0xff) % Int8

end  # module TSX
